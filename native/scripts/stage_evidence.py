#!/usr/bin/env python3
"""Split CI media and diagnostics while preserving paths for report merging."""
import argparse
import pathlib
import shutil


def stage(source, destination, platform):
    if destination.exists():
        shutil.rmtree(destination)
    for file in source.rglob('*'):
        if not file.is_file() or file.is_symlink():
            continue
        relative = file.relative_to(source)
        if platform == 'macOS' and not (
                relative.parts[0] == 'walkthrough'
                or (len(relative.parts) == 1 and file.name.startswith('native-') and file.suffix == '.png')
                or str(relative) in ('dependencies.txt', 'Testing/Temporary/LastTest.log')):
            continue
        if 'driver' in relative.parts:
            continue
        in_result = any(part.endswith('.xcresult') for part in relative.parts)
        category = ('Screenshots' if file.suffix.lower() == '.png' else
                    'Recordings' if file.suffix.lower() in ('.mp4', '.mov') else 'Diagnostics')
        if in_result:
            category = 'Diagnostics'
        target = destination / category / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('platform', choices=['macOS', 'iOS'])
    parser.add_argument('source', type=pathlib.Path)
    parser.add_argument('destination', type=pathlib.Path)
    args = parser.parse_args()
    stage(args.source.resolve(), args.destination.resolve(), args.platform)
