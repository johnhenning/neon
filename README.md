# Neon — native Apple preview

Neon is a local-first writing workspace with a portable C++23 core, AppKit on Mac,
and UIKit on iPad and iPhone. All three use the same semantic document/storage
adapter. No account is required for local writing.

## Current implementation

- Local project library; create projects and sections, navigate and resume writing.
- Stable project/document/section/block IDs with creator and last-editor metadata.
- Native text input, selection and per-section undo, debounced local save and reopen.
- Collapsible iPad chapter sidebar for full-width focus; compact iPhone navigation.
- Warm parchment/charcoal palette, bronze accents, bundled Literata manuscript font
  and Source Sans 3 controls. Adjustable text size/spacing and System/Light/Dark.
- Visible save errors; unsupported files are left unchanged.

This is a plain-text preview. Rich formatting/media, durable history, journaled
async storage, full accessibility/device acceptance and iCloud remain in progress.
Typography controls affect presentation, not semantic document formatting. The
Mac app is ad-hoc signed, not a notarized release. No performance claims are made.

## Build and test on Mac

```sh
python3 -m pip install clang-format==19.1.7 cpplint==2.0.2
git config core.hooksPath .githooks
python3 native/scripts/quality.py
cmake -S native -B build-native -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build build-native --parallel
ctest --test-dir build-native --output-on-failure
open build-native/NeonNative.app
```

The app uses `Application Support/Neon Apple Preview` in its platform container.
It never opens the earlier RTF prototype's library. Prior native and Qt prototypes
remain in their reference branches and PRs.

## iPhone and iPad simulators

```sh
cmake -S native -B build-ios -G Xcode -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build build-ios --config Debug --target NeonMobile
python3 native/scripts/ios_smoke.py build-ios/Debug-iphonesimulator/NeonMobile.app build-ios/evidence
```

CI builds Mac and iOS, exercises multi-section save/reopen, and captures native
screenshots. Physical-device signing and supported toolchain pinning remain work.
Build setup follows [CMake Apple toolchains](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-visionos-or-watchos).

## Portable core

```sh
cmake -S native/core -B build-core
cmake --build build-core
ctest --test-dir build-core --output-on-failure
```

See [architecture](native/ARCHITECTURE.md) and [font licenses](NOTICE.md).

## Inspiration

The early writing workflow was inspired by [Hugh Howey’s NEO](https://github.com/hughhowey/neo); Neon is an independent implementation.
