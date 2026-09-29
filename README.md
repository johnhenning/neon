# Neon — native Mac prototype

A separate, Qt-free native prototype inspired by [Hugh Howey’s NEO](https://github.com/hughhowey/neo). C++23 owns the portable application state; AppKit owns the Mac interface and text editor; a Foundation adapter owns local persistence. No Electron, Chromium or Qt dependencies in this app.

The earlier Qt implementation remains untouched in [PR #1](https://github.com/johnhenning/neon/pull/1), branch `feat/macos-native`. Its feature counts do not apply to this prototype.

## Build on macOS

```sh
python3 -m pip install clang-format==19.1.7 cpplint==2.0.2
git config core.hooksPath .githooks
python3 native/scripts/quality.py
cmake -S native -B build-native -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build build-native --parallel
ctest --test-dir build-native --output-on-failure
open build-native/NeonNative.app
```

CI uses macOS 26. The deployment setting is provisional; older OS compatibility is not yet validated. The app writes only to `~/Library/Application Support/Neon Native Prototype/library-v1.json`. The smoke test uses a disposable temporary library with fictional sample books and captures full desktop windows.

## Portable core on Linux

```sh
cmake -S native/core -B build-core
cmake --build build-core
ctest --test-dir build-core --output-on-failure
```

## Current prototype scope

- Native window, unified toolbar, visual-effect sidebar, book covers, system font panel and on-demand spelling action.
- Open/create books, select chapters, edit rich text through NSTextView, native text undo, debounced local save, save/reopen.
- Portable repository contract, revision conflict detection, retained drafts after save failures, Foundation JSON/base64 codec and atomic file replacement under an advisory process lock.
- Layer-backed views for Core Animation compositing. There is no custom Metal text renderer or continuous animation loop. Text layout/encoding may still execute on the CPU.

This is not Neo feature parity. The full Settings design, import/export, rich-text migration, durable revision history, iCloud/Git, and other frontends remain planned. See [architecture](native/ARCHITECTURE.md). The app is an ad-hoc-signed preview, not a notarized release.
