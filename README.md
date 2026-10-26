# Neon

**A native, local-first writing workspace for Mac, iPad, and iPhone.**

[![Native Apple foundation](https://github.com/johnhenning/neon/actions/workflows/native-macos.yml/badge.svg?branch=main)](https://github.com/johnhenning/neon/actions/workflows/native-macos.yml)

Neon brings manuscripts, chapter organization, and local version history into a
focused writing environment. AppKit and UIKit provide native editing, selection,
and undo; a shared C++23 document model keeps the underlying content portable.
Local writing does not require an account.

> **Developer preview.** Neon is under active development. Keep independent backups
> of important work. macOS builds are ad-hoc signed, not notarized; mobile downloads
> are Simulator builds, not device-installable applications.

[Build from source](#build-from-source) · [Architecture](native/ARCHITECTURE.md) ·
[Contributing](CONTRIBUTING.md) · [Releases](docs/RELEASING.md) · [Security](SECURITY.md)

## What works today

- **Project library:** create, rename, duplicate, trash, and restore local projects.
- **Chapter organization:** add, rename, duplicate, reorder, trash, and restore chapters.
- **Native writing:** text selection, section-local undo, debounced saves, and reopen support.
- **Writing presets:** Book, Research Paper, Newsletter, Essay, and Meeting Notes, with
  appropriate starter sections, terminology, and typography defaults.
- **Local history:** automatic snapshots, named checkpoints, searchable previews, and
  whole-project restore that preserves a “Before restore” checkpoint.
- **Reading preferences:** manuscript fonts, text size, line and paragraph spacing,
  writing-column width, appearance, spelling, and smart punctuation.
- **Adaptive navigation:** a collapsible chapter sidebar on iPad and compact navigation
  on iPhone.

The current document model is plain text. Rich formatting and media, import/export,
revision comparison, chapter-scoped restore, iCloud, and collaboration are not yet
supported. Complete accessibility, physical-device, recovery, and design acceptance
remain in progress. Presets provide writing structure; they do not yet provide
citation management, equation rendering, publication formatting, or newsletter sending.

## Architecture

| Layer | Responsibility |
| --- | --- |
| [`native/core`](native/core) | Portable C++23 document model, validation, presets, and commands |
| [`native/apple`](native/apple) | Shared Foundation persistence, sessions, history, preferences, and controls |
| [`native/macos`](native/macos) | AppKit interface and native Mac text editing |
| [`native/ios`](native/ios) | UIKit interface for iPad and iPhone |
| [`native/uitests`](native/uitests) | Recorded XCTest journeys against the CMake-built application |

The core has no dependency on Apple frameworks, Qt, or platform filesystem paths.
Native text systems own input and rendering. Earlier Qt and native prototypes are
retained in their reference branches and pull requests.

## Build from source

### Prerequisites

- Full Xcode with Command Line Tools selected for the Apple build and XCTest.
- CMake 3.24 or newer and a C++23-capable compiler.
- Python 3; the pinned formatting and lint dependencies below.
- XcodeGen and FFmpeg for recorded Apple UI journeys.

Deployment targets are **macOS 14+** and **iOS/iPadOS 17+**. CI uses the `macos-26`
runner; inspect the run logs for the actual Xcode and Simulator versions used.

From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install clang-format==19.1.7 cpplint==2.0.2
git config core.hooksPath .githooks
python native/scripts/quality.py
```

### macOS

```sh
cmake -S native -B build-native \
  -DCMAKE_BUILD_TYPE=Debug -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build build-native --parallel
ctest --test-dir build-native --output-on-failure
open build-native/Neon.app
```

The native smoke test requires a logged-in graphical session. Recorded walkthroughs
also need macOS accessibility/screen-recording access where prompted.

### iPhone and iPad Simulator

```sh
cmake -S native -B build-ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
cmake --build build-ios --config Debug --target NeonMobile
python native/scripts/ios_smoke.py \
  build-ios/Debug-iphonesimulator/Neon.app build-ios/evidence
```

This configuration targets Apple Silicon simulators. Physical-device distribution
requires a separate signing and provisioning setup.

### Portable core

The core can be built independently on a supported C++23 toolchain:

```sh
cmake -S native/core -B build-core -DCMAKE_BUILD_TYPE=Debug
cmake --build build-core --parallel
ctest --test-dir build-core --output-on-failure
```

## Validation and downloads

[Native Apple CI](https://github.com/johnhenning/neon/actions/workflows/native-macos.yml)
checks formatting and architecture boundaries, runs core/session tests, builds both
Apple applications, and records Mac, iPhone, and iPad UI journeys. Build artifacts,
screenshots, recordings, and diagnostics are stored separately in each workflow run.
Successful report generation does not substitute for passing native tests.

Published previews, when available, appear on the
[Releases page](https://github.com/johnhenning/neon/releases). The release workflow
creates an **unpublished draft** from a successful `main` build, with package checksums
and source provenance. See [release procedures](docs/RELEASING.md) for the validation
and manual publishing steps.

## Documents and data safety

Neon stores its library in `Application Support/Neon Apple Preview` within the
platform's application environment. It does not open the earlier RTF prototype's
library automatically.

Schema 3 stores sections, stable identifiers, preset roles, and local history in an
atomic JSON envelope. Schemas 1 and 2 are backed up before their first changed save;
unsupported or invalid data is rejected rather than overwritten. Older builds that
do not support schema 3 refuse it instead of silently dropping content.

History is local and includes section Trash. Restoring a snapshot creates a new
revision; it does not erase the current draft's checkpoint. Duplicating a project
starts independent history. Snapshots are not automatically pruned, so project files
grow over time. Journaled recovery and coordinated storage remain development work.
Typography preferences change presentation, not semantic document formatting.

## Project information

- [Contribution and validation guidelines](CONTRIBUTING.md)
- [Security reporting](SECURITY.md)
- [Repository maintenance policy](docs/REPOSITORY.md)
- [Third-party notices and font licenses](NOTICE.md)

The early writing workflow was inspired by [Hugh Howey’s NEO](https://github.com/hughhowey/neo).
Neon is an independent implementation. Third-party licenses are documented in `NOTICE.md`;
no additional license grant for the Neon source is implied by this README.
