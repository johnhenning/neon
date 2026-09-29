# Neon implementation plan

Status: approved for implementation. C++23 confirmed. macOS desktop feature parity is the first delivery goal; other platforms are deferred.

Execution priority update: build and verify macOS first. Preserve portable boundaries, but do not require mobile deliverables to pass the first release gate.

Prepared September 29, 2026. Target repository: https://github.com/johnhenning/neon

## 1. Goal and scope

Reimplement Neo from the ground up in C++ and Qt, retaining its novel-writing workflow while removing Electron, Chromium, Capacitor, and web-view dependencies. Deliver installable desktop and mobile applications with a shared core, adaptive interfaces, readable local files, and measured performance improvements.

The baseline is Neo commit `285c081065224aedb4e8c21c5d99f08ed616d217`, whose package identifies version 0.9.1. The initial audit covered README, tutorial, desktop source and menus, persistence, editing commands, export functions, and Pocket documentation. A complete behavioral checklist and fixture library are the first implementation deliverables. The supplied YouTube demo could not be retrieved; it is not treated as reviewed evidence.

Feature parity means matching supported user workflows and preserving manuscript semantics, not copying every pixel or reproducing existing bugs. Upstream roadmap items are distinguished from shipped features. Any omitted shipped feature must be explicitly accepted before declaring parity.

Proposed scope:

- Desktop: full audited Neo parity on macOS, Windows, and Linux.
- Mobile: shared manuscript functionality and at least Neo Pocket parity on iOS/iPadOS and Android. Normal software-keyboard support is required, even though Pocket documents limitations here.
- Mobile imports, exports, spellcheck, and email: reuse core services where feasible, but stage their mobile integration after the initial Pocket-parity milestone. Pocket currently excludes them; they are not silently counted as delivered.
- No accounts, hosted sync service, real-time collaboration, or new AI-writing features in the first release. Optional AI cover art remains in parity scope.
- No performance claims until comparable benchmarks have run.

## 2. Architecture

Use C++23, CMake, Qt 6, and Qt Quick/QML with Qt Quick Controls. Select and pin an available supported Qt release and compatible toolchains during milestone 0. Do not rely on commercial-only LTS access. Qt Quick is preferred to Qt Widgets for the shared touch/desktop interface. QML handles presentation and lightweight interaction; manuscript operations, storage, import/export, and application rules stay in C++.

Qt Quick has its own rendering and QML runtime. This is a compiled application without a browser engine, not a collection of OS-owned widgets. Use platform styles, native dialogs where available, standard keyboard conventions, and platform service adapters. Linux integration must be checked separately on GNOME and KDE.

| Component | Responsibility |
| --- | --- |
| `neon_core` | Book/chapter/scene models, stable identifiers, metadata, commands, anchors, goals, and change tracking |
| `neon_editor` | QTextDocument-based editing, cursor/selection, formatting, IME handling, structural commands, viewport management, and undo coordination |
| `neon_storage` | Neo codec, local repository, write journal, atomic per-file replacement, recovery, snapshots, and conflict detection |
| `neon_formats` | Import/export of text, Markdown, HTML, DOCX, EPUB, and PDF through an explicit intermediate manuscript representation |
| `neon_services` | On-demand spelling, cover rendering/generation, background jobs, and progress reporting |
| `neon_platform` | File access, secure credentials, sharing/email, lifecycle, OS menus, and packaging adapters |
| `neon_app` | C++ view models and QML desktop/mobile presentation |

Use typed interfaces at these boundaries. Keep source files small enough that storage or formatting changes do not require editing UI code. Avoid a generic plugin framework until there is a concrete need.

### C++ standard and portability policy — revised September 29, 2026

Use the newest practical standard across all release targets, rather than defaulting to C++20. The proposed baseline is C++23 mode with a verified shared feature set. This is not a claim that every C++23 language/library facility exists on every toolchain. Milestone 0 will pin and test the compiler, standard library, SDK, deployment target, Qt build and CMake combination for Windows, macOS, Linux, Android and iOS/iPadOS.

C++26 is platform-independent in design, but its implementations remain incomplete and inconsistent; enabling a dialect flag does not establish portable support. Do not require C++26-only facilities in the shared production core yet. Include a non-blocking C++26 forward-compatibility build where supported. Promote the baseline when every shipping toolchain passes the required language and library probes plus application tests. Use feature-test macros and configure-time compile/link probes for newly adopted facilities; avoid compiler-specific extensions and avoid maintaining two application implementations just to use newer syntax.

Apple compiler support and deployed libc++ runtime availability are separate constraints. Android must use an NDK compatible with the selected Qt binaries; do not upgrade the NDK independently without ABI verification. Platform-specific code may use newer supported facilities behind an interface that leaves the shared core portable. Any need to lower the proposed baseline or raise minimum OS versions must be documented during the feasibility review.

References: [GCC support](https://gcc.gnu.org/projects/cxx-status.html), [Clang support](https://clang.llvm.org/cxx_status.html), [Apple support](https://developer.apple.com/xcode/cpp/), [MSVC support](https://learn.microsoft.com/en-us/cpp/overview/visual-cpp-language-conformance), [Qt platform toolchains](https://doc.qt.io/qt-6/supported-platforms.html).

### Editor design and early decision gate

Prototype Qt Quick TextEdit backed by QTextDocument/QTextCursor through the documented QQuickTextDocument interface. This provides a mature starting point for rich text, shaping, selection, and editing rather than writing a text engine from scratch.

Do not assume Qt's HTML subset will preserve Neo's CSS, placeholder spans, scene markers, or drop caps. Define explicit manuscript blocks and inline attributes with codecs to and from the editable document. Preserve unknown metadata; do not silently normalize away unsupported source content. Keep unedited chapter files byte-identical when possible. Block unsafe migration or retain the original with a clear report.

Start with chapter-level documents, cached word counts, and bounded layout of nearby chapters. The target remains a continuous manuscript view with cross-chapter navigation and selection; chapter loading is an implementation detail, not an excuse to reduce editing capability. Test a pathological single long chapter as well as a many-chapter novel. If Qt's standard layout fails the performance or rich-layout tests, scope a focused custom layout/rendering component before implementing the rest of the UI. Do not commit to full custom rendering prematurely.

Typing undo and structural undo must form one predictable user history. Split/merge, Darlings moves, and Replace All are transaction-sized commands. Recovery journals are separate from the in-memory undo stack.

### Concurrency

Keep the live editor document and UI objects on their owning thread. Run indexing, independent document parsing, archive generation, backups, and network operations in workers using immutable snapshots or separately owned objects. Never pass the live QTextDocument to a worker. Bound caches and job queues; support cancellation and discard stale results. Keep filesystem/network work out of the typing path.

## 3. Files and manuscript safety

Retain Neo's recognizable folder layout: `library.json`, per-book `book.json`, chapter HTML, notes/outline HTML, Darlings, stickies, and cover assets. The initial goal is verified Neo import plus readable Neon storage; bidirectional compatibility must be proved against fixtures before advertised. Do not promise simultaneous editing by Neo and Neon.

- Open existing Neo libraries through a non-destructive migration/copy workflow by default. Report unsupported fields and retain the originals.
- Version the Neon schema and keep migration/recovery metadata in a separate namespace. Regenerable indexes may use SQLite; they must never be the only copy of manuscript content.
- Use stable chapter/block identifiers and context-aware anchors for Darlings and placeholders. When an original location is ambiguous, preserve the passage and offer recovery choices rather than guessing silently.
- Debounced saves persist changed chapters only. Flush on navigation, explicit save, orderly close, and mobile background transitions when the OS permits. Display unsaved/error state.
- Atomic replacement protects each file; a journal/manifest handles multi-file edits and recovery. Test interruption after each transaction stage.
- Detect external edits using revision information/content checks. Preserve both versions on conflict. Local locks do not provide cross-device locking through cloud folders.
- Daily ZIP snapshots with the upstream two-week retention behavior; retention only removes old snapshots after a new verified snapshot succeeds. Provide a restore flow and verify recovery from damaged metadata.
- Mobile file providers require dedicated adapters. Do not assume Android document URIs or iOS cloud documents behave like ordinary writable filesystem paths.

## 4. Feature-parity inventory

Every row becomes individually testable scenarios linked to upstream code and acceptance evidence.

| Area | Included workflows |
| --- | --- |
| Library | First-run setup; author and pen-name management; create/rename/reorder shelves; move/reorder books; metadata; remove/reshelve/delete behavior; library folder selection; progress on covers |
| Writing | Chapter creation, split/merge/reorder and renumbering; scene breaks; Enter/Enter/Enter workflow; poetry paragraphs; smart punctuation; rich formatting; paste/match style; undo/redo; selection and book/chapter word counts |
| Book-like appearance | Font selection, page theme and zoom, alignment, drop-cap variants, headings, distraction-free controls, fullscreen, typewriter scrolling, sentence/paragraph focus, pinned/hidden panels |
| Planning and revision | Notes; renamed auxiliary tabs; outline chapters and sections; ghost section notes; chapter/section conversions; Darlings with restoration anchors; placeholders and resolution; find/replace; on-demand spelling with personal dictionary |
| Momentum | Daily/book goals; configurable writing-day rollover; sprints; 30-day daily/cumulative progress; persistence across restarts |
| Covers | Deterministic seeded covers, layout/type variants, reroll, imported art, optional generated art, progress indicators, secure API-key storage, cancellable/retryable generation |
| Import | DOCX, TXT, Markdown; chapter/scene detection; title extraction; formatting retention; preview/report of interpretation and unsupported content |
| Export | TXT, Markdown, HTML, PDF, DOCX, EPUB 3; title/author/cover/TOC; chapter-title options; shelf anthology export; appropriate exclusion of internal annotations |
| Integrations | Timestamped PDF snapshot and SHA-256 fingerprint; email/share handoff without silently sending; platform file dialogs, clipboard, shortcuts, and update notifications/install path |
| Resilience | Autosave, close/background saving, daily backups, restore, external change detection, conflict preservation, migration/version handling |
| Localization/accessibility | Existing eight UI languages: English, French, Spanish, Portuguese, German, Italian, Dutch, Polish; spell-language inventory checked separately; keyboard navigation, labels, contrast, scaling, screen readers |
| Mobile | Shelf/book navigation, pen names, editor, notes/comments, outline and Darlings, adaptive panels, touch selection, software/hardware keyboards, back navigation, safe areas, local/cloud-provider access, lifecycle recovery |

Seeded and AI-generated covers need equivalent choices and workflows, not pixel-identical random output. Current network-provider API requirements will be verified when that adapter is implemented. No manuscript is uploaded without the writer enabling the relevant feature.

## 5. Delivery milestones and review gates

| Milestone | Reviewable result | Exit gate |
| --- | --- | --- |
| 0 — Baseline and feasibility | Source-linked parity checklist; representative Neo libraries; baseline benchmark harness; C++/Qt skeleton and editor spikes on desktop plus early Android/iOS builds | Prove IME, mobile selection, rich-text round trip, long-document layout, drop-cap feasibility, and dependency/licensing path; record any design changes |
| 1 — Safe writing vertical slice | Create/open book, edit formatted chapters, basic navigation, autosave/reopen, undo/redo, recovery; thin desktop and mobile shells | Save-failure and crash-recovery tests pass; usable writing session on physical mobile devices and desktop |
| 2 — Library and writing experience | Shelf/pen-name flows, metadata/covers, chapter and scene operations, typography, focus/typewriter modes, platform-adaptive controls | Core writing workflows and continuous-manuscript interaction demonstrated on all desktop OSes |
| 3 — Planning and revision | Notes/outline, ghost notes, Darlings, placeholders, find/replace, spelling, goals/sprints/charts | Structural edits undo correctly; anchors survive ordinary edits and fail safely when ambiguous |
| 4 — Interchange and integrations | All desktop import/export formats, anthology export, backups/restore, optional cover generation, PDF fingerprint/email handoff | Semantic fixture comparison, EPUB validation, DOCX/PDF rendering checks, restore drills; no silent loss of annotations or text |
| 5 — Mobile completion | Phone/tablet layouts, platform file providers, lifecycle, accessibility, touch and keyboard polish; remaining mobile services staged explicitly | Pocket parity checklist passes on iPhone/iPad and Android phone/tablet; any desktop-only capability visibly documented |
| 6 — Performance and release | Tuned builds, platform packages, signing/update integration, release notes, migration guide and measured comparison with Neo | Desktop parity matrix complete; agreed mobile scope complete; benchmark targets assessed; release-platform smoke and recovery checks pass |

Mobile engineering begins in milestone 0 and continues throughout; milestone 5 is not the first mobile port. Each milestone should produce runnable builds and a concise demonstration, with remaining parity gaps visible. Estimate calendar time after the feasibility spike and platform access are known rather than inventing a full-project deadline now.

## 6. Performance acceptance proposal

These are proposed goals, not existing results. Fix named reference hardware, OS, display refresh rate, build configuration, manuscript fixtures, cache state, and instrumentation before measurement. Compare against the pinned Neo revision using matched scenarios.

| Measurement | Initial target |
| --- | --- |
| Input-to-present latency | Desktop p95 at or below 33 ms on a 60 Hz display; verify composition separately; mobile target assessed on named devices |
| Scrolling | At least 95% of frames within the 16.7 ms budget during the agreed desktop scroll scenario |
| Cold launch to usable library | At or below 1 second with the agreed local 100-book metadata library on reference desktop hardware |
| Open 100,000-word manuscript | At or below 1 second to editable initial viewport; background completion reported separately |
| Resident memory | At least 50% lower than Neo in the matched manuscript scenario; report absolute RSS and peak RSS too |
| Autosave | Normal changed-chapter writes complete within 1 second after the debounce window on local SSD; no synchronous save in the keystroke handler |
| Idle behavior | No continuous rendering loop or periodic full-library scans; record CPU utilization and mobile energy behavior |

Also benchmark 10k, 100k, and 500k words, a single very long chapter, many short chapters, non-Latin text, image-heavy covers, and slow or unavailable file providers. Report distributions and outliers. Separate editor improvements from gains caused simply by loading less content. Add performance regression checks after baselines are stable, with tolerances that account for CI noise.

## 7. Verification and release engineering

Use Qt Test for C++ behavior, Qt Quick Test for UI interactions, integration fixtures for persistence/interchange, and platform-specific manual/device checks for IME, accessibility, dialogs and cloud providers. Add meaningful property/fuzz tests for format parsers, structural commands, and recovery boundaries.

Critical scenarios include emoji and combining characters; RTL and CJK composition; smart punctuation during composition; cross-chapter selection; formatting across splits; Darlings restoration after edits; placeholder relocation; Replace All undo; full disks; permission loss; process termination during saves; simultaneous external changes; timezone/day rollover; and mobile suspension.

Use Qt's text/PDF facilities for supported outputs, explicit XML/package writers for DOCX/EPUB, a maintained archive library for ZIP formats, and an on-demand spellchecker such as Hunspell after dependency review. Qt rich-text HTML support is not a DOCX or EPUB implementation. Validate EPUB packages with EPUBCheck and inspect representative documents in independent readers. Do not require exact pagination across different font installations.

CI: Linux, Windows, and macOS builds and tests; Android cross-build; iOS build on a suitable macOS runner. Initial proposed architectures: Windows x64, macOS Apple Silicon and Intel where the chosen SDK permits, Linux x64 with ARM64 follow-up, Android arm64, iOS/iPadOS arm64 plus simulator. Record exact minimum OS versions after pinning Qt; platform support is not inferred merely from compilation.

Deliver platform packages: macOS app/DMG, Windows installer, Linux AppImage or distro-compatible package, Android APK/AAB, and an iOS TestFlight/App Store path. Signing identities, Apple team access, and distribution secrets are release prerequisites, not prerequisites to designing and testing the core. Never place signing keys in source control.

Audit licenses for Qt modules, fonts, dictionaries, and archive libraries, including mobile distribution and any static linkage. Retain upstream MIT attribution for reused assets/translations or adapted code. Do not assume every Qt module uses the same license. Lock dependencies and create a software bill of materials for release.

## 8. Main risks and mitigations

| Risk | Mitigation / decision point |
| --- | --- |
| Qt text layout cannot meet book-like layout or long-chapter performance needs | Milestone 0 prototypes and benchmarks; isolated rendering/layout extension only if necessary |
| QTextDocument round trips lose Neo annotations or custom markup | Explicit codecs and semantic fixtures; preserve originals; reject unsupported conversion instead of dropping data |
| Structural commands diverge from editor undo history | One coordinated command boundary; test split/merge/Darlings/replace transactions before adding polish |
| Cloud folders produce conflicts or partial updates | Journaled transactions, revision checks, conflict copies, provider-specific handling; no assumed cloud locks |
| Mobile keyboards break desktop key handlers | Treat committed text/IME as primary input; hardware-key shortcuts are a separate layer; test real devices early |
| Packaging or license constraints surface late | Verify module/distribution choices in milestone 0; exercise packaging before feature completion |
| Feature parity is claimed too early | Per-feature evidence and per-platform status; explicit approval for scope changes |

Current execution-environment limitation: installing Qt build dependencies was blocked by network policy. Nothing has been compiled or performance-tested in this session. Implementation requires a permitted dependency source or suitable CI/development runner; this is included in milestone 0 rather than hidden behind an unverified build claim.

## 9. Proposed decisions for review

1. Approve C++23 + Qt Quick/QML with platform styling and native service adapters.
2. Approve full desktop parity and a separately tracked Pocket-parity mobile milestone, followed by desktop services on mobile where practical.
3. Approve non-destructive Neo migration first; bidirectional editing compatibility only after verification.
4. Approve an editor/storage/mobile feasibility gate before building the full interface.
5. Approve the benchmark targets as initial engineering goals, subject to documented revision after reference-device baselines.

After review, place the approved plan and parity checklist in Neon, add architecture decisions and contributor instructions, and implement milestone 0 on a development branch. No application code, dependency choice, package publication, or repository commit is represented as completed by this plan.

## References

- Pinned Neo source: https://github.com/hughhowey/neo/tree/285c081065224aedb4e8c21c5d99f08ed616d217
- Neo tutorial: https://github.com/hughhowey/neo/blob/285c081065224aedb4e8c21c5d99f08ed616d217/TUTORIAL.md
- Pocket scope: https://github.com/hughhowey/neo/blob/285c081065224aedb4e8c21c5d99f08ed616d217/pocket/README.md
- Qt Quick document integration: https://doc.qt.io/qt-6/qquicktextdocument.html
- Qt rich text: https://doc.qt.io/qt-6/qtextdocument.html
- Qt Quick TextEdit: https://doc.qt.io/qt-6/qml-qtquick-textedit.html
- Qt styles: https://doc.qt.io/qt-6/qtquickcontrols-styles.html
- Qt supported platforms: https://doc.qt.io/qt-6/supported-platforms.html
- Qt licensing: https://doc.qt.io/qt-6/licensing.html
