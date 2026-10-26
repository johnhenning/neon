"""Fail closed before creating a draft from verified main-branch CI artifacts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import zipfile

CHECKS = {'portable-core', 'macos-native', 'ios-native'}
ARTIFACTS = {'Neon-Native-macOS', 'Neon-Native-iOS-Simulator'}
PACKAGES = {'Neon.zip': 'Neon.app/Contents/Info.plist',
            'Neon-Simulator.zip': 'Neon.app/Info.plist'}


def version_number(tag):
    match = re.fullmatch(r'v(0\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))-preview\.([1-9][0-9]*)', tag)
    if not match:
        raise ValueError('Use v0.MINOR.PATCH-preview.N (N starts at 1)')
    return match[1]


def validate_source(run, jobs, artifacts, repository):
    if (run.get('repository', {}).get('full_name') != repository
            or run.get('head_repository', {}).get('full_name') != repository
            or run.get('path') != '.github/workflows/native-macos.yml'
            or run.get('event') != 'push' or run.get('head_branch') != 'main'
            or run.get('status') != 'completed' or run.get('conclusion') != 'success'):
        raise ValueError('Release source must be a successful Native Apple foundation push to main')
    for name in CHECKS:
        matches = [job for job in jobs if job['name'] == name]
        if len(matches) != 1 or matches[0].get('conclusion') != 'success':
            raise ValueError(f'Required job did not pass: {name}')
    for name in ARTIFACTS:
        matches = [item for item in artifacts if item['name'] == name]
        if len(matches) != 1 or matches[0].get('expired') or matches[0].get('size_in_bytes', 0) <= 0:
            raise ValueError(f'Missing, ambiguous, empty or expired artifact: {name}')
    if not re.fullmatch(r'[0-9a-f]{40}', run.get('head_sha', '')):
        raise ValueError('Source commit is invalid')
    return run['head_sha']


def api(path):
    return json.loads(subprocess.check_output(['gh', 'api', path], text=True))


def pages(path, key):
    result = []
    page = 1
    while True:
        response = api(f'{path}?per_page=100&page={page}')
        batch = response[key] if key else response
        result.extend(batch)
        if len(batch) < 100:
            return result
        page += 1


def package(assets, tag, sha, run_id, repository):
    expected = version_number(tag)
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('Source commit is invalid')
    hashes = {}
    for name, info_path in PACKAGES.items():
        path = assets / name
        with zipfile.ZipFile(path) as archive:
            entries = [item for item in archive.infolist() if item.filename == info_path]
            if len(entries) != 1 or entries[0].file_size > 1024 * 1024:
                raise ValueError(f'Invalid app metadata in {name}')
            info = plistlib.loads(archive.read(entries[0]))
            if info.get('CFBundleShortVersionString') != expected:
                raise ValueError(f'{name} version must match {expected}')
            expected_id = ('com.johnhenning.neon.nativeprototype' if name == 'Neon.zip'
                           else 'com.johnhenning.neon.applepreview')
            if info.get('CFBundleIdentifier') != expected_id or info.get('CFBundleExecutable') != 'Neon':
                raise ValueError(f'Unexpected application in {name}')
        digest = hashlib.sha256()
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        hashes[name] = digest.hexdigest()
    (assets / 'SHA256SUMS').write_text(''.join(f'{value}  {name}\n' for name, value in hashes.items()))
    (assets / 'provenance.json').write_text(json.dumps({
        'schema': 1, 'tag': tag, 'source_sha': sha, 'repository': repository,
        'workflow_run': int(run_id), 'workflow_url': f'https://github.com/{repository}/actions/runs/{run_id}',
        'sha256': hashes, 'distribution': 'developer preview; macOS ad-hoc signed, iOS Simulator only'
    }, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['verify', 'package'])
    parser.add_argument('--tag', required=True)
    parser.add_argument('--run-id', required=True, type=int)
    parser.add_argument('--sha')
    parser.add_argument('--assets', type=Path)
    args = parser.parse_args()
    version_number(args.tag)
    if args.run_id <= 0:
        raise ValueError('Run ID must be positive')
    repo = os.environ['GH_REPO']
    if args.command == 'verify':
        base = f'repos/{repo}/actions/runs/{args.run_id}'
        sha = validate_source(api(base), pages(base + '/jobs', 'jobs'),
                              pages(base + '/artifacts', 'artifacts'), repo)
        if any(release.get('tag_name') == args.tag for release in pages(f'repos/{repo}/releases', None)):
            raise ValueError('Release or draft already exists; choose a new preview number')
        # Existing refs/releases must never be replaced or reused by this workflow.
        for endpoint in [f'repos/{repo}/git/ref/tags/{args.tag}',
                         f'repos/{repo}/releases/tags/{args.tag}']:
            probe = subprocess.run(['gh', 'api', endpoint], capture_output=True, text=True)
            if probe.returncode == 0:
                raise ValueError('Tag or release already exists; choose a new preview number')
            if '(HTTP 404)' not in probe.stderr:
                raise RuntimeError(probe.stderr)
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(f'sha={sha}\n')
    else:
        if not args.assets or not args.sha:
            parser.error('package requires --assets and --sha')
        package(args.assets, args.tag, args.sha, args.run_id, repo)


if __name__ == '__main__':
    main()
