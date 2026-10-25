#!/usr/bin/env python3
"""Regression tests for native job selection and Git diff semantics."""
import os
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import json

from ci_paths import changed_paths, classify, main


class SelectionTests(unittest.TestCase):
    def test_platform_dependencies(self):
        cases = [
            (['native/macos/NativeApp.mm'], (True, False, False)),
            (['native/ios/Info.plist'], (False, True, False)),
            (['native/core/CMakeLists.txt'], (True, True, True)),
            (['native/apple/Settings.mm'], (True, True, False)),
            (['native/resources/fonts/font.ttf'], (True, True, False)),
            (['native/CMakeLists.txt'], (True, True, False)),
            (['native/scripts/ios_smoke.py'], (False, True, False)),
            (['native/scripts/focus_log.py'], (False, True, False)),
            (['native/scripts/ui_walkthrough.py'], (True, True, True)),
            (['.github/workflows/apple-report.yml'], (True, True, True)),
            (['README.md', 'native/README.md', 'docs/design.md'], (False, False, False)),
            (['native/apple/README.md', 'native/core/design.md',
              'native/macos/design.markdown', 'native/ios/README.MD'], (False, False, False)),
            (['native/resources/fonts/Example-OFL.txt'], (True, True, False)),
        ]
        for paths, expected in cases:
            with self.subTest(paths=paths):
                self.assertEqual(tuple(classify(paths).values()), expected)

    def test_platform_concurrency_is_independent(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        workflow = (root / '.github/workflows/native-macos.yml').read_text()
        self.assertNotIn('concurrency:', workflow.split('jobs:', 1)[0])
        for job, platform in [('portable-core', 'core'), ('macos-native', 'macos'),
                              ('ios-native', 'ios')]:
            section = workflow.split(f'  {job}:', 1)[1].split('    runs-on:', 1)[0]
            self.assertIn(f'group: native-apple-{platform}-', section)
            self.assertIn('cancel-in-progress: true', section)

    def test_report_jobs_do_not_outlive_cancelled_workflows(self):
        root = pathlib.Path(__file__).resolve().parents[2]
        native = (root / '.github/workflows/native-macos.yml').read_text()
        for platform in ('macos', 'ios'):
            section = native.split(f'  report-{platform}:', 1)[1].split('    permissions:', 1)[0]
            self.assertIn('always() && !cancelled()', section)
            self.assertIn(f"needs.{platform}-native.result != 'skipped'", section)
        report = (root / '.github/workflows/apple-report.yml').read_text()
        publish = report.split('  publish:', 1)[1].split('    runs-on:', 1)[0]
        self.assertIn('always() && !cancelled()', publish)

    def test_dispatch(self):
        with tempfile.NamedTemporaryFile() as output:
            with patch.dict(os.environ, GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_OUTPUT=output.name):
                main()
            self.assertEqual(pathlib.Path(output.name).read_text(), 'macos=true\nios=true\ncore=true\n')

    def test_cumulative_diff_deletion_rename_and_base_advancement(self):
        previous = os.getcwd()
        with tempfile.TemporaryDirectory() as directory:
            try:
                os.chdir(directory)
                def git(*args):
                    return subprocess.check_output(['git', *args], text=True).strip()
                git('init', '-q')
                git('config', 'user.name', 'CI Test')
                git('config', 'user.email', 'ci@example.invalid')
                path = pathlib.Path('native/macos/old.mm')
                path.parent.mkdir(parents=True)
                path.write_text('original')
                git('add', '.')
                git('commit', '-qm', 'base')
                base = git('rev-parse', 'HEAD')
                git('checkout', '-qb', 'feature')
                new = pathlib.Path('native/ios/new.mm')
                new.parent.mkdir(parents=True)
                path.rename(new)
                git('add', '-A')
                git('commit', '-qm', 'move platform')
                pathlib.Path('README.md').write_text('docs')
                git('add', '.')
                git('commit', '-qm', 'second push docs')
                head = git('rev-parse', 'HEAD')
                first_push = git('rev-parse', 'HEAD^')
                event_path = pathlib.Path(directory) / 'event.json'
                output_path = pathlib.Path(directory) / 'job-output'
                def selection(before, action='synchronize'):
                    output_path.write_text('')
                    event_path.write_text(json.dumps({'action': action, 'before': before,
                        'pull_request': {'base': {'sha': base}, 'head': {'sha': head}}}))
                    with patch.dict(os.environ, GITHUB_EVENT_NAME='pull_request',
                                    GITHUB_EVENT_PATH=str(event_path), GITHUB_OUTPUT=str(output_path)):
                        main()
                    return output_path.read_text()
                self.assertEqual(selection(first_push), 'macos=false\nios=false\ncore=false\n')
                self.assertEqual(selection('missing'), 'macos=true\nios=true\ncore=false\n')
                self.assertEqual(selection(first_push, 'opened'), 'macos=true\nios=true\ncore=false\n')
                # A later iOS-only push must not re-run the earlier macOS change.
                new.write_text('iOS update')
                git('add', 'native/ios/new.mm')
                git('commit', '-qm', 'iOS followup')
                before = head
                head = git('rev-parse', 'HEAD')
                self.assertEqual(selection(before), 'macos=false\nios=true\ncore=false\n')
                event_path.unlink()
                output_path.unlink()
                git('checkout', '-q', base)
                pathlib.Path('native/core').mkdir()
                pathlib.Path('native/core/unrelated.cpp').write_text('base only')
                git('add', '.')
                git('commit', '-qm', 'base advances')
                paths = changed_paths(git('rev-parse', 'HEAD'), head)
                self.assertEqual(set(paths), {'native/macos/old.mm', 'native/ios/new.mm', 'README.md'})
                self.assertEqual(classify(paths), dict(macos=True, ios=True, core=False))
            finally:
                os.chdir(previous)


if __name__ == '__main__':
    unittest.main()
