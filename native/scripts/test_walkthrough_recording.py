"""Verify XCTest recording success is independent of the simulator fallback."""
import json
import pathlib
import plistlib
import tempfile
import unittest
from unittest.mock import Mock, patch

import ui_walkthrough


class RecordingOrchestrationTests(unittest.TestCase):
    def test_successful_test_with_valid_xctest_and_missing_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            app = root / 'Neon.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': 'com.johnhenning.neon.applepreview',
                'CFBundleExecutable': 'Neon'}))
            output = root / 'evidence'

            def fake_run(*args, **kwargs):
                if args[:2] == ('xcodebuild', 'build-for-testing'):
                    products = output / 'driver/DerivedData/Build/Products'
                    (products / 'Debug/NeonHost.app').mkdir(parents=True)
                    (products / 'driver.xctestrun').write_bytes(plistlib.dumps({
                        'TestConfigurations': [{'TestTargets': [{}]}]}))
                elif args[:2] == ('xcodebuild', 'test-without-building'):
                    config = plistlib.loads((output / 'driver/DerivedData/Build/Products/driver.xctestrun').read_bytes())
                    target = config['TestConfigurations'][0]['TestTargets'][0]
                    self.assertEqual(target['DefaultTestExecutionTimeAllowance'], 180)
                    self.assertEqual(target['MaximumTestExecutionTimeAllowance'], 240)
                    self.assertTrue(target['TestTimeoutsEnabled'])
                    bundle = output / 'walkthrough.xcresult'
                    bundle.mkdir()
                    (bundle / 'Info.plist').touch()
                elif args[:4] == ('xcrun', 'xcresulttool', 'export', 'attachments'):
                    attachments = output / 'attachments'
                    attachments.mkdir()
                    (attachments / 'genuine-xctest.mp4').write_bytes(b'fixture' * 200)
                elif args[0] == 'ffmpeg':
                    self.assertEqual(pathlib.Path(args[args.index('-i') + 1]).name,
                                     'genuine-xctest.mp4')
                    pathlib.Path(args[-1]).write_bytes(b'encoded' * 200)

            recorder = Mock()
            recorder.poll.return_value = 1
            with patch('sys.argv', ['ui_walkthrough.py', 'iPhone', str(app), str(output),
                                    '--device', 'test-device']), \
                 patch.object(ui_walkthrough, 'run', side_effect=fake_run), \
                 patch.object(ui_walkthrough.subprocess, 'Popen', return_value=recorder), \
                 patch.object(ui_walkthrough.time, 'sleep'), \
                 patch.object(ui_walkthrough, 'capture_context', return_value={}), \
                 patch.object(ui_walkthrough, 'write_manifest'), \
                 patch.object(ui_walkthrough, 'validate_video', return_value={'status': 'passed'}):
                self.assertEqual(ui_walkthrough.main(), 0)
            result = json.loads((output / 'result.json').read_text())
            self.assertEqual(result['ui_status'], 'passed')
            self.assertEqual(result['recording_status'], 'passed')
            self.assertTrue(result['video_complete'])
            self.assertEqual(result['recording_source'], 'XCTest system attachment')
            self.assertFalse((output / 'iPhone-walkthrough.mov').exists())


if __name__ == '__main__':
    unittest.main()
