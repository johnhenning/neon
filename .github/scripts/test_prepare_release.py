import copy
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

from prepare_release import ARTIFACTS, CHECKS, PACKAGES, package, validate_source, version_number


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.repo = 'johnhenning/neon'
        self.sha = 'a' * 40
        self.run = {'repository': {'full_name': self.repo}, 'head_repository': {'full_name': self.repo},
                    'path': '.github/workflows/native-macos.yml', 'event': 'push', 'head_branch': 'main',
                    'status': 'completed', 'conclusion': 'success', 'head_sha': self.sha}
        self.jobs = [{'name': name, 'conclusion': 'success'} for name in CHECKS]
        self.artifacts = [{'name': name, 'expired': False, 'size_in_bytes': 100} for name in ARTIFACTS]

    def test_valid_source(self):
        self.assertEqual(validate_source(self.run, self.jobs, self.artifacts, self.repo), self.sha)

    def test_reject_wrong_branch_event_status_or_workflow(self):
        for key, value in [('head_branch', 'feature'), ('event', 'pull_request'),
                           ('status', 'in_progress'), ('conclusion', 'failure'), ('path', 'other.yml')]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_source(dict(self.run, **{key: value}), self.jobs, self.artifacts, self.repo)

    def test_reject_missing_failed_or_duplicate_jobs(self):
        for jobs in [self.jobs[:-1], self.jobs + self.jobs[:1],
                     [dict(job, conclusion='failure') for job in self.jobs]]:
            with self.assertRaises(ValueError):
                validate_source(self.run, jobs, self.artifacts, self.repo)

    def test_reject_expired_artifacts_and_foreign_source(self):
        artifacts = copy.deepcopy(self.artifacts)
        artifacts[0]['expired'] = True
        with self.assertRaises(ValueError):
            validate_source(self.run, self.jobs, artifacts, self.repo)
        run = dict(self.run, head_repository={'full_name': 'someone/fork'})
        with self.assertRaises(ValueError):
            validate_source(run, self.jobs, self.artifacts, self.repo)

    def test_preview_versions_only(self):
        self.assertEqual(version_number('v0.3.0-preview.1'), '0.3.0')
        for tag in ['v1.0.0', 'v0.3.0', 'v0.3.0-preview.0', 'v0.03.0-preview.1', 'v0.3.0-preview.1\n']:
            with self.assertRaises(ValueError):
                version_number(tag)

    def write_packages(self, directory, version='0.3.0'):
        for name, info_path in PACKAGES.items():
            bundle = ('com.johnhenning.neon.nativeprototype' if name == 'Neon.zip'
                      else 'com.johnhenning.neon.applepreview')
            with zipfile.ZipFile(directory / name, 'w') as archive:
                archive.writestr(info_path, plistlib.dumps({'CFBundleShortVersionString': version,
                                  'CFBundleIdentifier': bundle, 'CFBundleExecutable': 'Neon'}))

    def test_package_provenance_and_checksums(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.write_packages(directory)
            package(directory, 'v0.3.0-preview.1', self.sha, 123, self.repo)
            self.assertEqual(len((directory / 'SHA256SUMS').read_text().splitlines()), 2)
            self.assertEqual(json.loads((directory / 'provenance.json').read_text())['source_sha'], self.sha)

    def test_version_mismatch_produces_no_manifest(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            self.write_packages(directory, version='0.2.0')
            with self.assertRaises(ValueError):
                package(directory, 'v0.3.0-preview.1', self.sha, 123, self.repo)
            self.assertFalse((directory / 'provenance.json').exists())


if __name__ == '__main__':
    unittest.main()
