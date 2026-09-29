#!/usr/bin/env python3
"""Build an external-app XCTest driver and record actual UI input on Apple runners."""
import argparse
import json
import pathlib
import plistlib
import shutil
import signal
import subprocess
import time


def run(*args, **kwargs):
    return subprocess.run(args, check=True, timeout=600, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['macOS', 'iPhone', 'iPad'])
    parser.add_argument('app', type=pathlib.Path)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--device')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    work = output / 'driver'
    work.mkdir(exist_ok=True)
    platform = 'macOS' if args.platform == 'macOS' else 'iOS'
    source = pathlib.Path(__file__).resolve().parents[1] / 'uitests/Walkthrough.swift'
    shutil.copy(source, work / source.name)
    # Xcode requires a host target to generate its UI runner. This build-only shell
    # is never launched: UITargetAppPath below points to the real CMake product.
    (work / 'Host.swift').write_text('@main struct Host { static func main() {} }\n')
    bundle_id = ('com.johnhenning.neon.nativeprototype' if platform == 'macOS'
                 else 'com.johnhenning.neon.applepreview')
    spec = {
        'name': 'NeonWalkthrough',
        'settings': {'base': {'SWIFT_VERSION': '5.0', 'GENERATE_INFOPLIST_FILE': 'YES',
                              'CODE_SIGNING_ALLOWED': 'NO'}},
        'targets': {
            'NeonHost': {'type': 'application', 'platform': platform,
                'deploymentTarget': '14.0' if platform == 'macOS' else '17.0',
                'sources': ['Host.swift'], 'settings': {'base': {
                    'PRODUCT_BUNDLE_IDENTIFIER': bundle_id}}},
            'Walkthrough': {'type': 'bundle.ui-testing', 'platform': platform,
            'dependencies': [{'target': 'NeonHost'}],
            'deploymentTarget': '14.0' if platform == 'macOS' else '17.0',
            'sources': ['Walkthrough.swift'], 'settings': {'base': {
                'PRODUCT_BUNDLE_IDENTIFIER': 'com.johnhenning.neon.walkthrough',
                'TEST_TARGET_NAME': 'NeonHost'}}}},
        'schemes': {'Walkthrough': {'build': {'targets': {'Walkthrough': ['test']}},
                                   'test': {'targets': ['Walkthrough']}}}
    }
    (work / 'project.json').write_text(json.dumps(spec))
    result = {'platform': args.platform, 'status': 'failed', 'video': 'missing',
              'interaction': 'XCTest accessibility clicks/taps and text input'}
    recorder = None
    try:
        run('xcodegen', 'generate', '--spec', str(work / 'project.json'), '--project', str(work))
        destination = 'platform=macOS' if platform == 'macOS' else f'platform=iOS Simulator,id={args.device}'
        derived = work / 'DerivedData'
        run('xcodebuild', 'build-for-testing', '-project', str(work / 'NeonWalkthrough.xcodeproj'),
            '-scheme', 'Walkthrough', '-destination', destination, '-derivedDataPath', str(derived))
        test_run = next(derived.glob('Build/Products/*.xctestrun'))
        config = plistlib.loads(test_run.read_bytes())
        # Xcode builds the UI runner; install/launch the exact app produced by CMake.
        targets = [t for c in config.get('TestConfigurations', []) for t in c['TestTargets']]
        if not targets:
            targets = [v for k, v in config.items() if not k.startswith('__') and isinstance(v, dict)]
        for target in targets:
            target['UITargetAppPath'] = str(args.app.resolve())
            target['UITargetAppBundleIdentifier'] = bundle_id
        test_run.write_bytes(plistlib.dumps(config))
        movie = output / f'{args.platform}-walkthrough.mov'
        if platform == 'macOS':
            record_args = ['/usr/sbin/screencapture', '-v', '-k', '-V', '180', str(movie)]
        else:
            record_args = ['xcrun', 'simctl', 'io', args.device, 'recordVideo', '--codec=h264', str(movie)]
        with (output / 'recording.log').open('w') as record_log:
            recorder = subprocess.Popen(record_args, stdout=record_log, stderr=subprocess.STDOUT)
            time.sleep(2)
            if recorder.poll() is not None:
                raise RuntimeError('Video recorder failed to start; see recording.log')
            try:
                run('xcodebuild', 'test-without-building', '-xctestrun', str(test_run),
                    '-destination', destination, '-parallel-testing-enabled', 'NO',
                    '-resultBundlePath', str(output / 'walkthrough.xcresult'))
                result['status'] = 'passed'
            finally:
                if recorder.poll() is None:
                    recorder.send_signal(signal.SIGINT)
                try:
                    recorder.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    recorder.kill()
                    recorder.wait()
        if not movie.exists() or movie.stat().st_size < 1024:
            raise RuntimeError('No usable video was produced')
        result['video'] = movie.name
    except (subprocess.SubprocessError, RuntimeError, StopIteration) as error:
        result['error'] = str(error)
        result['status'] = 'failed'
    finally:
        bundle = output / 'walkthrough.xcresult'
        if bundle.exists():
            try:
                run('xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle),
                    '--output-path', str(output / 'attachments'))
            except subprocess.SubprocessError as error:
                result['attachment_error'] = str(error)
        (output / 'result.json').write_text(json.dumps(result, indent=2))
        shutil.rmtree(work, ignore_errors=True)
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
