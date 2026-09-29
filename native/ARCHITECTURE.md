# Native prototype architecture

## Direction and boundaries

The user approved preserving the Qt reference while creating a separate native Mac prototype. This branch starts independently from main and adds only the native slice and its development tooling. It must not be merged as a claim of equivalent functionality to the Qt preview.

AppKit UI -> C++ Workspace -> LibraryRepository interface <- MacRepository adapter.

- `core/include/neon/workspace.h`: portable DTOs and persistence contract. No OS paths, Apple types or Qt dependencies.
- `core/src/workspace.cpp`: create/update/save state, revision advancement, dirty-state retention and identifier invariants. Repository injection supports platform-independent tests.
- `macos/MacRepository.mm`: Foundation JSON and RTF-byte serialization, location handling, atomic replacement, advisory lock and compare-before-save conflict detection. The UI composition root injects this adapter.
- `macos/NativeApp.mm`: window, native toolbar/sidebar, cover presentation, NSTextView input, platform word segmentation, font panel and native event loop. macOS objects stay here. Initially AppKit is used directly; a SwiftUI shell could later consume the same application boundary without moving persistence into views.

Rich text currently consists of UTF-8 text plus opaque RTF payload bytes. This is an explicit prototype compromise, not the final cross-platform model. A future normalized semantic document model needs stable blocks/runs, annotations and lossless Neo codecs. The portable core does not parse or render RTF. Preserve source manuscripts and validate round trips before offering migration.

## Rendering

Layer-backed AppKit views let Core Animation composite cached view contents using the platform graphics stack when available. Native scroll/text input remain AppKit-owned. Custom covers draw on invalidation and cache in backing layers. No permanent frame timer or forced redraw loop runs while idle. This does not imply all drawing, shaping or layout runs on the GPU, or that virtualization supplies hardware acceleration.

Validate on physical Apple Silicon with Instruments/Core Animation: typing latency, scrolling frame pacing, layer count, memory, idle activity, font/layout hot spots and large manuscripts. Respect Reduce Motion; the current prototype adds no ornamental animation. Custom Metal is deferred until profiling identifies a workload that requires it.

## Persistence and failure policy

The prototype owns a separate local directory and versioned JSON envelope. Saves check the durable revision while holding an advisory lock; an external revision or malformed file blocks replacement and leaves the in-memory draft dirty. Atomic replacement protects a single library file; power-loss durability, remote filesystem behavior and schema upgrades need further validation. No cloud transaction guarantee is made.

Do not point this adapter at a Neo library, shared provider or Git working directory. Do not silently fall back to empty data after a load error. The current whole-library snapshot and RTF serialization happen on the UI thread and are acceptable only for this small prototype; move snapshot I/O to a serialized worker before scaling. Close/quit is blocked on save failure. Recovery-copy export and crash journaling are not implemented yet.

## Validation and next gates

Portable fake-repository tests cover duplicate IDs, save failures, retained drafts, reopen, opaque rich payloads and external revision conflict. macOS smoke uses the actual NSTextView, edits a sample chapter, saves via the C++ core and Foundation repository, and reopens to verify text and rich payload. CI records linked libraries and rejects Qt/Electron/Chromium dependencies. Formatting/lint run before commits and in CI.

Next gates: inspect native render; validate dark mode, accessibility/IME and focus; add explicit rich-text semantic model and adapter integration fault tests; isolate background persistence; implement the reviewed Settings structure; migrate parity features incrementally. Do not count Qt features as native features. iCloud and Git remain planned adapters with separate conflict semantics.

Original inspiration: Hugh Howey’s NEO, MIT licensed; see NOTICE.md and NEO-LICENSE.
