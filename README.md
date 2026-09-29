# Neon

A native C++23 / Qt 6 novel-writing application, reimplemented from the ground up with macOS desktop as the first release target. No Electron, Chromium or web views.

Implementation is in progress. See [the plan](docs/implementation-plan.md) and the implementation branch for the current build and feature status.

Upstream behavioral reference: [Hugh Howey's Neo](https://github.com/hughhowey/neo), MIT licensed. Neon is not an official Neo release.

## Build on macOS

Install CMake, a C++23-capable Xcode toolchain, Qt 6.10.3, and Python 3. CI uses the `macos-26` GitHub Actions runner.

```sh
cmake -S . -B build -DCMAKE_PREFIX_PATH=/path/to/Qt/6.10.3/macos -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
open build/Neon.app
```

The default library is `~/Documents/Neon Library`. Use `--library /path/to/library` to select a separate library. Development builds should use copies of manuscripts.

## Quality checks

```sh
python3 -m pip install clang-format==19.1.7 cpplint==2.0.2
git config core.hooksPath .githooks
python3 scripts/quality.py
```

Put Qt's `bin` directory on PATH for `qmlformat`. Run `python3 scripts/quality.py --fix` to apply formatting. The pre-commit hook and CI run the same formatting, C++ lint, QML syntax, and whitespace checks.

## Screenshots

The UI smoke test creates a temporary sample library, renders the bookshelf and editor, and saves `bookshelf.png` and `editor.png` in its working directory. It does not use the default manuscript library. CI publishes these as `Neon-macOS-screenshots`, with the test log, and includes them in the preview artifact when packaging succeeds.

These are captures from the actual Qt application. They demonstrate the current interface; they do not establish feature parity. See [current parity status](docs/parity.md).
