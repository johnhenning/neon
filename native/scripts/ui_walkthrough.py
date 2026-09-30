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
    # is replaced with the real CMake product before running any tests.
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
        destination = 'platform=macOS,arch=arm64' if platform == 'macOS' else f'platform=iOS Simulator,id={args.device}'
        derived = work / 'DerivedData'
        run('xcodebuild', 'build-for-testing', '-project', str(work / 'NeonWalkthrough.xcodeproj'),
            '-scheme', 'Walkthrough', '-destination', destination, '-derivedDataPath', str(derived))
        test_run = next(derived.glob('Build/Products/*.xctestrun'))
        config = plistlib.loads(test_run.read_bytes())
        # XCTest has additional bundle-ID and dependency mappings beyond UITargetAppPath.
        # Keep the generated mappings consistent by replacing the host bundle in place.
        hosts = list(derived.glob('Build/Products/*/NeonHost.app'))
        if len(hosts) != 1:
            raise RuntimeError(f'Expected one UI host bundle, found {len(hosts)}')
        host = hosts[0]
        shutil.rmtree(host)
        shutil.copytree(args.app.resolve(), host, symlinks=True)
        info_path = host / ('Contents/Info.plist' if platform == 'macOS' else 'Info.plist')
        app_info = plistlib.loads(info_path.read_bytes())
        if app_info['CFBundleIdentifier'] != bundle_id or app_info['CFBundleExecutable'] != 'Neon':
            raise RuntimeError('UI host does not contain the expected CMake-built Neon app')
        targets = [t for c in config.get('TestConfigurations', []) for t in c['TestTargets']]
        if not targets:
            targets = [v for k, v in config.items() if not k.startswith('__') and isinstance(v, dict)]
        for target in targets:
            target['TestTimeoutsEnabled'] = True
            target['DefaultTestExecutionTimeAllowance'] = 120
            target['MaximumTestExecutionTimeAllowance'] = 180
            if platform == 'macOS':
                target['SystemAttachmentLifetime'] = 'keepAlways'
        test_run.write_bytes(plistlib.dumps(config))
        (output / 'test-launch.json').write_text(json.dumps({
            'source_app': str(args.app.resolve()), 'test_app': str(host),
            'bundle_id': app_info['CFBundleIdentifier'],
            'executable': app_info['CFBundleExecutable']}, indent=2))
        movie = output / f'{args.platform}-walkthrough.mov'
        if platform == 'macOS':
            # XCTest already records the real UI session. Keep its recording on
            # success too, avoiding an independent screencapture process whose
            # SIGINT shutdown can discard the movie on hosted Mac runners.
            run('xcodebuild', 'test-without-building', '-xctestrun', str(test_run),
                '-destination', destination, '-parallel-testing-enabled', 'NO',
                '-resultBundlePath', str(output / 'walkthrough.xcresult'))
            result['status'] = 'passed'
        else:
            record_args = ['xcrun', 'simctl', 'io', args.device, 'recordVideo', '--codec=h264', str(movie)]
        if platform != 'macOS':
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
        if platform != 'macOS' and (not movie.exists() or movie.stat().st_size < 1024):
            raise RuntimeError('No usable video was produced')
    except (subprocess.SubprocessError, RuntimeError, StopIteration) as error:
        result['error'] = str(error)
        result['status'] = 'failed'
    finally:
        result['ui_status'] = result['status']
        movie = output / f'{args.platform}-walkthrough.mov'
        bundle = output / 'walkthrough.xcresult'
        if (bundle / 'Info.plist').exists():
            try:
                run('xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle),
                    '--output-path', str(output / 'attachments'))
            except subprocess.SubprocessError as error:
                result['attachment_error'] = str(error)
        try:
            if platform == 'macOS':
                recordings = list((output / 'attachments').glob('*.mp4'))
                if len(recordings) != 1:
                    raise RuntimeError(f'Expected one XCTest recording, found {len(recordings)}')
                original = recordings[0]
            else:
                original = movie
            movie = output / f'{args.platform}-walkthrough.mp4'
            with (output / 'video-export.log').open('w') as record_log:
                run('ffmpeg', '-y', '-i', str(original), '-an',
                    '-vf', 'scale=960:960:force_original_aspect_ratio=decrease:force_divisible_by=2,fps=24',
                    '-c:v', 'libx264', '-b:v', '500k', '-maxrate', '650k', '-bufsize', '1300k',
                    '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(movie),
                    stdout=record_log, stderr=subprocess.STDOUT)
            result['recording_source'] = ('XCTest system attachment' if platform == 'macOS'
                                          else 'simctl recordVideo')
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            result['recording_error'] = str(error)
            result['status'] = 'failed'
        if movie.exists() and movie.stat().st_size >= 1024:
            result['video'] = movie.name
            result['video_complete'] = result['status'] == 'passed'
        else:
            result['status'] = 'failed'
            result['recording_error'] = result.get('recording_error', 'No usable video was produced')
        (output / 'result.json').write_text(json.dumps(result, indent=2))
        shutil.rmtree(work, ignore_errors=True)
    return 0 if result['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
