# Neon — native Apple preview

Neon is a local-first writing workspace with a portable C++23 core, AppKit on Mac,
and UIKit on iPad and iPhone. All three use the same semantic document/storage
adapter. No account is required for local writing.

## Current implementation

- Local project library; create, rename and duplicate projects, move them to Trash,
  restore them, or confirm permanent deletion from Trash.
- Create, rename, duplicate, reorder, trash and restore chapters; valid empty state
  after removing the final chapter.
- Stable project/document/section/block IDs with creator and last-editor metadata.
- Native text input, selection and per-section undo, debounced local save and reopen.
- Collapsible iPad chapter sidebar for full-width focus; compact iPhone navigation.
- Warm parchment/charcoal palette, bronze accents, bundled Literata manuscript font
  and Source Sans 3 controls. Adjustable text size/spacing and System/Light/Dark.
- Custom project/chapter/text action popovers, available from context and overflow menus.
- Font previews and live typography popovers/sheets. Searchable Writing and Appearance
  settings include paragraph spacing, column width, spelling, smart punctuation and
  word-count visibility, with confirmed device-preference reset.
- Visible save errors; unsupported files are left unchanged.

This is a plain-text preview. Rich formatting/media, revision comparison, journaled
async storage, full accessibility/device acceptance and iCloud remain in progress.
Additional settings categories and project/export scopes, structural undo and exact
design acceptance remain open.
Schema 3 retains section roles, presets, and local history. Schemas 1 and 2 are read
and backed up before their first updated save. Earlier builds refuse schema 3
instead of dropping retained content.
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
open build-native/Neon.app
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
python3 native/scripts/ios_smoke.py build-ios/Debug-iphonesimulator/Neon.app build-ios/evidence
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

### Writing presets and local history

New projects can start as a Book, Research Paper, Newsletter, Essay, or Meeting Notes.
Each preset supplies its own document/section terminology, starter outline, semantic section
roles, and writing guidance. Renaming a heading preserves its role. The editor uses preset
font and paragraph defaults (device font/paragraph preferences can override them), academic
line spacing, and hanging reference paragraphs. These are reading/editing formats, not
journal submission styles or export guarantees. References and URLs remain plain text;
citation management, LaTeX, rich hyperlinks/media, and newsletter sending are still future work.

Open **History** in the Mac sidebar/File menu or mobile editor actions/outline toolbar.
Automatic snapshots are captured on changed saves, at most once per minute. Named
checkpoints capture the current project exactly. Search and preview are read-only. Restore
creates a new revision and retains the current draft as a **Before restore** checkpoint;
its scope is the entire project, including section Trash. History is local, not cloud sync,
collaborative review, or per-keystroke undo. Diff views, checkpoint renaming, scoped restore,
and retention controls remain open.

Schema 3 stores preset/section roles and history in one atomic JSON envelope. Schemas 1 and 2
are backed up byte-for-byte before first changed save; backups follow project Trash/restore.
Unknown or invalid content/history is refused without overwriting the file. History travels
with the project; a duplicated project begins its own history. Snapshots retain full text
and are not pruned automatically, so files grow over time. A scalable asynchronous journal,
file coordination, and recovery remain release prerequisites.
