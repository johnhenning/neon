#!/usr/bin/env python3
"""Boot an available iPhone and iPad; exercise native edit/save/reopen and capture."""
import json
import pathlib
import re
import subprocess
import sys
import time

app = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
bundle = 'com.johnhenning.neon.applepreview'


def run(*args):
    print('simctl', *args, flush=True)
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True, timeout=300).strip()


runtimes = json.loads(run('list', 'runtimes', '-j'))['runtimes']
runtime = max((item for item in runtimes if item.get('isAvailable') and 'iOS' in item['name']),
              key=lambda item: tuple(int(v) for v in re.findall(r'\d+', item['version'])))
types = json.loads(run('list', 'devicetypes', '-j'))['devicetypes']
devices = json.loads(run('list', 'devices', 'available', '-j'))['devices']
for family in ['iPhone', 'iPad']:
    existing = next(item for item in devices[runtime['identifier']] if family in item['name'])
    kind = next(item for item in types if item['name'] == existing['name'])
    udid = run('create', f'Neon CI {family}', kind['identifier'], runtime['identifier'])
    device = {'name': kind['name'], 'udid': udid}
    booted_here = True
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
    except (SystemExit, subprocess.SubprocessError):
        # Preserve the failed surface and markers before deleting the disposable simulator.
        try:
            run('io', udid, 'screenshot', str(output / f'{family}-failure.png'))
        except subprocess.SubprocessError as error:
            print(f'Could not capture failed simulator: {error}', flush=True)
        if 'container' in locals():
            for result in (container / 'Library/Application Support').glob('smoke-*.txt'):
                (output / f'{family}-{result.name}').write_bytes(result.read_bytes())
        raise
    finally:
        if booted_here:
            run('shutdown', udid)
            run('delete', udid)
