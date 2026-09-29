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

## Apple foundation slice

`native/core/document.h` (under `include/neon`) introduces an independent semantic
Project/Document/Section/text-block model. The existing Mac RTF prototype remains
usable while its editor adapter is migrated in a subsequent slice. No Neo import
is planned. This is not a rich-text format freeze.

The new `NeonMobile` UIKit target runs on both iPhone and iPad and uses the shared
C++ document model through `NeonDocumentSession`, a Foundation-only bridge also
built/tested on macOS. It supports one local plain-text draft, native keyboard/
selection/undo, debounced save, explicit save and background flush. Its isolated
Application Support file never opens the old Mac prototype library. Native undo
is the only undo authority for this initial whole-block editing slice.

On a Mac with Xcode and an iOS simulator runtime:

```sh
cmake -S native -B build-ios -G Xcode -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build build-ios --config Debug --target NeonMobile
python3 native/scripts/ios_smoke.py build-ios/Debug-iphonesimulator/NeonMobile.app build-ios/evidence
```

CI builds the Mac prototype, runs Foundation codec/storage tests, and launches
both iPhone and iPad simulators. Deployment targets and system fonts are provisional;
full design tokens, library navigation, rich text/media, per-change history,
coordination/journaled storage, async I/O, physical-device signing and iCloud are
not complete. Background callbacks alone do not guarantee recovery after termination.
This preview performs small synchronous writes and is not ready for long manuscripts.
The codec rejects unsupported schemas, extra fields and richer structures without
overwriting them. A production codec must preserve extensions and all document
structures. Creator/last-editor metadata is not a full authorship ledger.

Build setup follows [CMake Apple toolchains](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-visionos-or-watchos).
