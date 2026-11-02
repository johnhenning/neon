"""An invalid XCTest clip must not hide a valid simulator recording."""
import pathlib
import tempfile
import unittest
from unittest import mock

from ui_walkthrough import export_validated_recording


class RecordingFallbackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.primary = self.root / 'xctest.mp4'
        self.backup = self.root / 'simulator.mov'
        self.backup.touch()

    def export(self, platform='iOS', recordings=None):
        return export_validated_recording(
            [self.primary] if recordings is None else recordings, self.backup,
            self.root / 'preview.mp4', self.root / 'export.log', platform)

    @mock.patch('ui_walkthrough.run')
    @mock.patch('ui_walkthrough.validate_video')
    def test_invalid_primary_uses_validated_backup(self, validate, run):
        validate.side_effect = [{'status': 'failed'}, {'status': 'passed'}]
        result = self.export()
        self.assertEqual(result['recording_status'], 'passed')
        self.assertIn('simctl', result['recording_source'])
        self.assertEqual([call.args[3] for call in run.call_args_list],
                         [str(self.primary), str(self.backup)])
        self.assertEqual(len(result['recording_attempts']), 2)

    @mock.patch('ui_walkthrough.run')
    @mock.patch('ui_walkthrough.validate_video', return_value={'status': 'passed'})
    def test_valid_primary_is_preferred(self, validate, run):
        self.assertEqual(self.export()['recording_source'], 'XCTest system attachment')
        self.assertEqual(run.call_count, 1)

    @mock.patch('ui_walkthrough.run')
    @mock.patch('ui_walkthrough.validate_video', return_value={'status': 'failed'})
    def test_both_invalid_fail_closed(self, validate, run):
        with self.assertRaisesRegex(RuntimeError, 'No validated recording'):
            self.export()
        self.assertEqual(run.call_count, 2)

    @mock.patch('ui_walkthrough.run')
    @mock.patch('ui_walkthrough.validate_video', return_value={'status': 'failed'})
    def test_mac_does_not_use_simulator_backup(self, validate, run):
        with self.assertRaisesRegex(RuntimeError, 'No validated recording'):
            self.export(platform='macOS')
        self.assertEqual(run.call_count, 1)

    @mock.patch('ui_walkthrough.run')
    def test_ambiguous_xctest_recordings_fail(self, run):
        with self.assertRaisesRegex(RuntimeError, 'Expected one XCTest recording'):
            self.export(recordings=[self.primary, self.primary])
        run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
