#!/usr/bin/env python3
"""Boot an available iPhone and iPad; exercise native edit/save/reopen and capture."""
import json
import pathlib
import subprocess
import sys
import time

app = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
bundle = 'com.johnhenning.neon.applepreview'


def run(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True, timeout=300).strip()


devices = json.loads(run('list', 'devices', 'available', '-j'))['devices']
for family in ['iPhone', 'iPad']:
    choices = [device for runtime, items in devices.items() if '.iOS-' in runtime
               for device in items if device.get('isAvailable') and family in device['name']]
    if not choices:
        raise SystemExit(f'No available {family} simulator')
    device = choices[0]
    udid = device['udid']
    booted_here = device['state'] != 'Booted'
    try:
        if booted_here:
            run('boot', udid)
        run('bootstatus', udid, '-b')
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
        for mode in ['library', 'focus']:
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
                raise SystemExit(f'{family}: {mode} navigation failed')
            time.sleep(2)
            run('io', udid, 'screenshot', str(output / f'{family}-{mode}.png'))
            run('terminate', udid, bundle)
        run('ui', udid, 'appearance', 'dark')
        run('launch', udid, bundle, '--smoke-reopen')
        time.sleep(3)
        run('io', udid, 'screenshot', str(output / f'{family}-dark.png'))
        run('terminate', udid, bundle)
    finally:
        if booted_here:
            run('shutdown', udid)
