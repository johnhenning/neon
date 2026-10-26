#!/usr/bin/env python3
"""Boot an available iPhone and iPad; exercise native edit/save/reopen and capture."""
import json
import pathlib
import re
import subprocess
import sys
import time

from focus_log import capture_focus_log


def run(*args):
    print('simctl', *args, flush=True)
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True, timeout=300).strip()


def select_simulator(runtimes, device_types, family):
    """Choose the newest available iOS runtime advertising this device family.

    Runtime compatibility is authoritative; installed default devices and their
    user-editable names are irrelevant when creating disposable test devices.
    """
    types_by_id = {item['identifier']: item for item in device_types}
    available = sorted(
        (item for item in runtimes if item.get('isAvailable') and item['name'].startswith('iOS ')),
        key=lambda item: tuple(int(v) for v in re.findall(r'\d+', item['version'])),
        reverse=True)
    for runtime in available:
        for supported in runtime.get('supportedDeviceTypes', []):
            identifier = supported.get('identifier') or supported.get('deviceTypeIdentifier')
            kind = types_by_id.get(identifier)
            if kind and (supported.get('productFamily') or kind.get('productFamily')) == family:
                return runtime, kind
    raise ValueError(f'No available iOS runtime supports {family}')


def main():
    app = pathlib.Path(sys.argv[1]).resolve()
    output = pathlib.Path(sys.argv[2]).resolve()
    output.mkdir(parents=True, exist_ok=True)
    bundle = 'com.johnhenning.neon.applepreview'
    runtimes = json.loads(run('list', 'runtimes', '-j'))['runtimes']
    types = json.loads(run('list', 'devicetypes', '-j'))['devicetypes']
    failures = []
    for family in ['iPhone', 'iPad']:
        runtime, kind = select_simulator(runtimes, types, family)
        udid = run('create', f'Neon CI {family}', kind['identifier'], runtime['identifier'])
        device = {'name': kind['name'], 'udid': udid}
        booted_here = True
        container = None
        try:
            if booted_here:
                run('boot', udid)
            # Fresh Apple runtimes can spend more than five minutes in first-boot migration.
            # This allowance does not relax any application assertion or marker deadline.
            subprocess.run(['xcrun', 'simctl', 'bootstatus', udid, '-b'], check=True, timeout=600)
            run('install', udid, str(app))
            container = pathlib.Path(run('get_app_container', udid, bundle, 'data'))
            marker = container / 'Library/Application Support/smoke-result.txt'
            marker.unlink(missing_ok=True)
            run('launch', udid, bundle, '--smoke-test')
            deadline = time.monotonic() + 45
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(1)
            if not marker.exists() or marker.read_text() != 'PASS':
                raise SystemExit(f'{family}: native edit/save/reopen did not pass')
            run('io', udid, 'screenshot', str(output / f'{family}.png'))
            (output / f'{family}.txt').write_text(f"PASS: {device['name']} {udid}\n")
            run('terminate', udid, bundle)
            # Reopen the same fixture through a fresh process, without resetting it.
            reopened = marker.with_name('smoke-reopen.txt')
            reopened.unlink(missing_ok=True)
            run('launch', udid, bundle, '--smoke-reopen')
            deadline = time.monotonic() + 30
            while not reopened.exists() and time.monotonic() < deadline:
                time.sleep(1)
            if not reopened.exists() or reopened.read_text() != 'PASS':
                raise SystemExit(f'{family}: process relaunch lost document text')
            run('io', udid, 'screenshot', str(output / f'{family}-reopened.png'))
            run('terminate', udid, bundle)
            for mode in ['library', 'focus', 'typography', 'menu', 'settings', 'history']:
                if mode == 'focus' and family != 'iPad':
                    continue
                mode_marker = marker.with_name(f'smoke-{mode}.txt')
                mode_marker.unlink(missing_ok=True)
                run('ui', udid, 'appearance', 'dark' if mode == 'focus' else 'light')
                run('launch', udid, bundle, f'--smoke-{mode}')
                deadline = time.monotonic() + 30
                while not mode_marker.exists() and time.monotonic() < deadline:
                    time.sleep(1)
                if not mode_marker.exists() or mode_marker.read_text() != 'PASS':
                    result = mode_marker.read_text() if mode_marker.exists() else 'no result marker (test did not finish)'
                    raise SystemExit(f'{family}: {mode} navigation failed: {result}')
                time.sleep(2)
                run('io', udid, 'screenshot', str(output / f'{family}-{mode}.png'))
                run('terminate', udid, bundle)
            run('ui', udid, 'appearance', 'dark')
            run('launch', udid, bundle, '--smoke-reopen')
            time.sleep(3)
            run('io', udid, 'screenshot', str(output / f'{family}-dark.png'))
            run('terminate', udid, bundle)
            run('ui', udid, 'appearance', 'light')
            run('launch', udid, bundle, '--smoke-preset')
            preset_marker = marker.with_name('smoke-preset.txt')
            deadline = time.monotonic() + 30
            while not preset_marker.exists() and time.monotonic() < deadline:
                time.sleep(1)
            if not preset_marker.exists() or preset_marker.read_text() != 'PASS':
                raise SystemExit(f'{family}: preset creation failed')
            time.sleep(2)
            run('io', udid, 'screenshot', str(output / f'{family}-research.png'))
            run('terminate', udid, bundle)
            with capture_focus_log(udid, output / family / 'focus-diagnostics.log'):
                subprocess.run([sys.executable, str(pathlib.Path(__file__).with_name('ui_walkthrough.py')),
                                family, str(app), str(output / family), '--device', udid],
                               check=True, timeout=900)
        except (SystemExit, subprocess.SubprocessError) as error:
            failures.append(f'{family}: {error}')
            (output / f'{family}-failure.txt').write_text(str(error))
            # Preserve the failed surface and markers before deleting the disposable simulator.
            try:
                run('io', udid, 'screenshot', str(output / f'{family}-failure.png'))
            except subprocess.SubprocessError as error:
                print(f'Could not capture failed simulator: {error}', flush=True)
            if container is not None:
                for result in (container / 'Library/Application Support').glob('smoke-*.txt'):
                    (output / f'{family}-{result.name}').write_bytes(result.read_bytes())
        finally:
            # XCTest can redirect NSLog away from unified logging. Preserve the bounded
            # window event trace from app storage before deleting this simulator.
            if container is not None:
                try:
                    current = pathlib.Path(run('get_app_container', udid, bundle, 'data'))
                    trace = current / 'Library/Application Support/neon-focus-diagnostics.log'
                    if trace.exists():
                        target = output / family / 'focus-window-diagnostics.log'
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(trace.read_bytes())
                except (OSError, subprocess.SubprocessError) as error:
                    print(f'Could not export focus window diagnostics: {error}', flush=True)
            if booted_here:
                run('shutdown', udid)
                run('delete', udid)

    if failures:
        raise SystemExit('\n'.join(failures))


if __name__ == '__main__':
    main()
