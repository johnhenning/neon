"""Exercise real encoding and decoding so frozen footage cannot pass validation."""
import pathlib
import subprocess
import tempfile
import unittest

from video_validation import validate_video


class VideoValidationTests(unittest.TestCase):
    def encode(self, directory, source):
        path = pathlib.Path(directory) / 'fixture.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', source,
                        '-t', '5', '-pix_fmt', 'yuv420p', str(path)], check=True, timeout=30)
        return path

    def test_frozen_movie_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            result = validate_video(self.encode(directory, 'color=c=black:s=96x96:r=24'))
            self.assertEqual(result['status'], 'failed')
            self.assertEqual(result['changed_transitions'], 0)

    def test_moving_movie_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            result = validate_video(self.encode(directory, 'testsrc2=s=96x96:r=24'))
            self.assertEqual(result['status'], 'passed')
            self.assertGreaterEqual(result['changed_transitions'], 2)

    def test_invalid_movie_fails_decoding(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'invalid.mp4'
            path.write_bytes(b'not a movie')
            with self.assertRaises(subprocess.CalledProcessError):
                validate_video(path)


if __name__ == '__main__':
    unittest.main()
