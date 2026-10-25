#!/usr/bin/env python3
"""Select native CI jobs from validated push or PR diffs, without API writes."""
import json
import os
import pathlib
import subprocess


def classify(paths):
    selected = {'macos': False, 'ios': False, 'core': False}
    for path in paths:
        # Markdown references are documentation even beside platform sources.
        if pathlib.PurePosixPath(path).suffix.lower() in {'.md', '.markdown'}:
            continue
        if path.startswith('native/core/'):
            selected.update(macos=True, ios=True, core=True)
        elif path.startswith('native/macos/'):
            selected['macos'] = True
        elif path in {'native/scripts/ios_smoke.py', 'native/scripts/focus_log.py'}:
            selected['ios'] = True
        elif path.startswith('native/ios/'):
            selected['ios'] = True
        elif (path.startswith(('native/apple/', 'native/resources/', 'native/scripts/'))
              or path == 'native/CMakeLists.txt'
              or path.startswith('.github/workflows/')):
            selected.update(macos=True, ios=True)
            if path.startswith(('native/scripts/', '.github/workflows/')):
                selected['core'] = True
        elif path.startswith('native/') and pathlib.PurePosixPath(path).suffix.lower() not in {'.md', '.txt'}:
            # New native dependency directories must not silently miss coverage.
            selected.update(macos=True, ios=True, core=True)
    return selected


def changed_paths(base, head):
    ancestor = subprocess.check_output(['git', 'merge-base', base, head], text=True).strip()
    # Treat a rename as deletion + addition so moves across platforms select both.
    raw = subprocess.check_output(['git', 'diff', '--no-renames', '--name-only', '-z', ancestor, head])
    return [path.decode('utf-8', errors='surrogateescape') for path in raw.split(b'\0') if path]


def main():
    event_name = os.environ['GITHUB_EVENT_NAME']
    if event_name == 'pull_request':
        event = json.loads(pathlib.Path(os.environ['GITHUB_EVENT_PATH']).read_text())
        pr = event['pull_request']
        head = pr['head']['sha']
        base = pr['base']['sha']
        # Synchronize events describe this push. Validate the previous commit
        # before using it; force pushes or unavailable history use the PR diff.
        before = event.get('before', '')
        if event.get('action') == 'synchronize' and before and set(before) != {'0'}:
            exists = subprocess.run(['git', 'cat-file', '-e', before + '^{commit}'],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            if exists and subprocess.run(['git', 'merge-base', '--is-ancestor', before, head]).returncode == 0:
                base = before
        selected = classify(changed_paths(base, head))
    else:
        # Manual runs (and future event types) always validate every target.
        selected = dict(macos=True, ios=True, core=True)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        for key, value in selected.items():
            output.write(f'{key}={str(value).lower()}\n')
    print(json.dumps(selected, sort_keys=True))


if __name__ == '__main__':
    main()
