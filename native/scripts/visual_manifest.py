#!/usr/bin/env python3
"""Capture provenance without inventing native viewport or OS measurements."""
import hashlib
import json
import pathlib
import platform
import subprocess


def capture_context(root, fixture, profile, figma_node, target, device=None):
    sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    dirty = bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip())
    return {'source_sha': sha, 'source_dirty': dirty, 'platform': target,
            'host_os': platform.platform(), 'device': device,
            'runtime_os': 'recorded by XCTest in capture attachments',
            'fixture': fixture, 'preference_profile': profile, 'figma_node': figma_node}


def write_manifest(output, context):
    captures = []
    native_metadata = []
    for path in sorted((output / 'attachments').rglob('*.json')):
        try:
            value = json.loads(path.read_text())
            if isinstance(value, dict) and 'capture' in value and 'viewport' in value:
                native_metadata.append(value)
        except (OSError, ValueError):
            continue
    for path in sorted((output / 'attachments').rglob('*')):
        if path.suffix.lower() in {'.png', '.jpg', '.jpeg'}:
            captures.append({'file': str(path.relative_to(output)),
                             'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                             'viewport': 'see matching XCTest capture metadata attachment'})
    # Native point bounds and OS are attached by XCTest, rather than guessed from
    # simulator names or the runner host's macOS version.
    (output / 'visual-manifest.json').write_text(json.dumps(
        {'schema': 1, **context, 'captures': captures, 'native_capture_metadata': native_metadata}, indent=2) + '\n')
