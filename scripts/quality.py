#!/usr/bin/env python3
"""Identical pre-commit and CI quality checks; missing tools fail closed."""
import argparse
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

def tool(*names):
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    sys.exit("Missing quality tool: " + " or ".join(names))

def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fix", action="store_true")
    args = parser.parse_args()
    cpp = sorted(str(p.relative_to(ROOT)) for folder in ("src", "tests")
                 for p in (ROOT / folder).glob("*") if p.suffix in {".cpp", ".h", ".mm"})
    formatter = tool("clang-format-19", "clang-format")
    version = subprocess.check_output([formatter, "--version"], text=True)
    if "version 19." not in version:
        sys.exit("Use clang-format 19.x to keep formatting reproducible")
    run([formatter, *( ["-i"] if args.fix else ["--dry-run", "--Werror"]), *cpp])
    run([sys.executable, "-m", "cpplint", "--extensions=cpp,h,mm", *cpp])
    qmlformat = tool("qmlformat", "pyside6-qmlformat")
    for p in sorted((ROOT / "qml").glob("*.qml")):
        if args.fix:
            run([qmlformat, "-i", str(p)])
        else:
            formatted = subprocess.check_output([qmlformat, str(p)], cwd=ROOT)
            if formatted != p.read_bytes():
                sys.exit(f"Run scripts/quality.py --fix: {p.name}")
        # qmlformat parses QML before formatting. Type-aware qmllint runs
        # after CMake generates the C++ module metadata in CI.
    run(["git", "diff", "--check"])
    print("C++ format/lint, QML format/syntax, and whitespace checks passed")

if __name__ == "__main__":
    main()
