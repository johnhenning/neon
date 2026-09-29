#!/usr/bin/env python3
"""Native prototype formatting, lint and architectural dependency checks."""
import argparse
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--fix', action='store_true')
args = parser.parse_args()
formatter = shutil.which('clang-format-19') or shutil.which('clang-format')
if not formatter or 'version 19.' not in subprocess.check_output([formatter, '--version'], text=True):
    sys.exit('clang-format 19.x is required')
files = sorted(str(p.relative_to(ROOT)) for p in (ROOT / 'native').rglob('*')
               if p.suffix in {'.h', '.cpp', '.mm'})
subprocess.run([formatter, *(['-i'] if args.fix else ['--dry-run', '--Werror']), *files], cwd=ROOT, check=True)
subprocess.run([sys.executable, '-m', 'cpplint', '--extensions=cpp,h,mm', *files], cwd=ROOT, check=True)
for path in (ROOT / 'native/core').rglob('*'):
    if path.suffix in {'.h', '.cpp'}:
        text = path.read_text()
        if any(token in text for token in ['#import', '<AppKit/', '<Foundation/', '<Qt', '<QObj', 'QTextDocument']):
            sys.exit(f'Platform dependency in portable core: {path}')
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
print('Native formatting, lint and dependency checks passed')
