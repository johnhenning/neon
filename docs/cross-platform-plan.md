# Cross-platform architecture review and implementation plan

Status: proposed architecture; implementation remains macOS-first.
Reviewed: 2026-09-29. Baseline: `3d181d9e06bf8a7007c072aef9e0a01e1ddb2c7e`.

Neon is a ground-up C++23/Qt application inspired by Hugh Howey’s [Neo](https://github.com/hughhowey/neo). This plan preserves that feature-parity goal. It does not claim Windows, Linux, iOS, or Android support is already working.

## Recommendation

Keep one shared C++23 application model and editing engine, with Qt providing the portable UI and runtime. Introduce small injected services only where operating-system behavior differs. Keep native SDK objects inside platform adapters. Use platform-specific home experiences and desktop/tablet/phone shells around shared editor, bookshelf, and book-detail components. macOS, iOS and iPadOS must support iCloud; this is an explicit product requirement, not an optional future enhancement.

Do the dependency separation during macOS development. Bring Windows and Linux to feature parity after the macOS acceptance milestone. Treat mobile as a deliberate document-access, lifecycle, and interaction project, not just a smaller window. No Electron or web views are needed.

## Findings in the current implementation

| Location | Finding | Required change |
| --- | --- | --- |
| `src/platform.h` | Six synchronous free functions return strings or booleans | Inject typed service interfaces with explicit failure, cancellation, and capability results |
| `src/platform.cpp` | Non-Mac spelling returns empty lists; secrets silently fail; sharing only opens the PDF | Report unsupported operations accurately; add real adapters before claiming parity |
| `src/platform_mac.mm` | AppKit spelling/email and Security Keychain are already isolated | Preserve this boundary, separate responsibilities, enforce UI-thread requirements, add completion handling |
| `CMakeLists.txt` | `if(APPLE)` links AppKit for all Apple targets | Distinguish macOS from iOS; select exactly one implementation per target |
| `src/main.cpp` | Assumes a writable Documents/Neon Library path; flushes when inactive | Centralize storage location policy and restoration; add foreground recovery and mobile lifecycle handling |
| `src/controller.cpp` | Imports, covers, exports call `toLocalFile()`; PDF exporter takes a path | Add document handles and stream-based transfers; retain local staging for path-only codecs |
| `src/store.cpp` | Transactions and lock assume a local filesystem | Keep transactional working storage local; do not treat a cloud provider as a POSIX directory |
| `src/controller.cpp` | Persistence, formatting, UI state, OS integration, and long-running jobs live together | Extract focused application services incrementally |
| `qml/Main.qml` | Desktop minimum width, fixed sidebars, monolithic UI, several literal Ctrl shortcuts | Shared commands and responsive components; mobile navigation, touch, IME and accessibility work |
| CI | macOS 26 only; packaging uses macdeployqt and codesign | Add desktop build matrix, then mobile builds and device validation |
| Build baseline | CMake accepts Qt 6.8 while CI uses 6.10.3 | Align and pin the supported toolchain policy; test C++23 features against each compiler/standard library |

## Proposed boundaries

Dependency direction: UI shells -> presentation models -> application services -> document model and storage. Application services depend on platform interfaces; the executable constructs the selected adapters. The core does not select a platform or import native SDK headers.

Suggested targets and directories:

- `neon_domain` / `src/domain`: book/chapter metadata, document operations, word counts, goals, revision rules. Qt Core types are acceptable; a Qt-free rewrite adds little value.
- `neon_document` / `src/document`: rich-text representation and format conversion. Qt Gui may remain necessary for QTextDocument and PDF. Preserve unknown Neo markup deliberately.
- `neon_application` / `src/application`: library, editor session, import/export, backups and command orchestration.
- `neon_platform` / `src/platform`: contracts, factory and selected macos/windows/linux/ios/android implementations; native dependencies private to these targets.
- `neon_ui` / `qml`: shared components and presentation models, desktop/mobile shells, design tokens.
- `tests/fakes`: configurable service implementations for deterministic cancellation, permission, unavailable-provider and failure tests.

Do not wrap QString, QTimer, QClipboard, ordinary networking, all file I/O, or every Qt control in a second portability framework. Reuse Qt directly when its semantics already match the requirement.

## Platform-specific home experiences

Home is an application workflow, not one responsive page. Share book cards, recents, shelf models, search, sync badges and commands; compose them differently for each platform. Define `HomeModel` for data and `HomePolicy` for sections/actions, with dedicated Mac, Windows/Linux, iPad and iPhone views. Do not scatter operating-system checks through book cards or editor components.

| Platform | Proposed home content and actions |
| --- | --- |
| macOS | Continue writing, recent books, local libraries and iCloud library in the sidebar, shelves/pen names, import/open, sync activity and conflicts; keyboard navigation and multiple-window behavior |
| iPadOS | Touch-friendly library sidebar, local and iCloud locations, recents, pinned/offline books, Files import, sync state; adapt to split view, hardware keyboards and multitasking |
| iOS | Continue writing first, recent/offline books and quick new-book action; compact library navigation, iCloud/download state and Files import; important actions remain reachable without desktop menus |
| Windows/Linux | Recents, local libraries, shelves, import/open and recovery; expose only implemented providers. Do not advertise Apple iCloud library sync on these platforms |
| Android | Continue writing, local/offline library, document-provider import/export and share; cloud integrations can be added through the same contract later |

Each home must handle empty library, account unavailable, offline, pending upload, not downloaded, permission lost, conflict and recovery states. “Saved on this device” and “Synced with iCloud” are distinct. Resolve conflicts and failures from the home screen without blocking access to unrelated books. iPadOS shares the iOS native adapter but has its own home/navigation composition.

## Apple iCloud requirement and proposed design

Provide both automatic Neon library synchronization across Mac/iPhone/iPad and iCloud Drive import/export through system document access. These are different integrations: CloudKit data is not automatically a visible folder in Files or Finder.

**Proposed default: local-first library plus a CloudKit private-database sync adapter**, with CKSyncEngine evaluated in a small signed prototype. Existing C++ persistence remains the local source for editing; CloudKit is a replication destination/source. Apple supplies scheduling and change-transfer support, but Neon still owns durable local updates, merge rules and recovery. Keep this choice provisional until the prototype proves the requirements and supported OS floors. User-visible, directly editable iCloud Drive manuscript packages are an alternative product mode requiring a separate storage decision; do not run two sync systems over the same live library.

Add `SyncService` and `LibraryLocation` contracts alongside `DocumentAccess`. The shared layer owns revisions, dirty state, durable outgoing changes, conflicts, tombstones and account-scoped library identity. `AppleCloudSync` owns CloudKit records, account/container access, transport tokens and platform callbacks. No CloudKit objects or entitlements appear in the portable document model. Use Objective-C++ where the SDK permits; isolate a small Swift bridge only if it materially simplifies a required API.

Prototype record granularity per book/chapter and separate library metadata/cover assets. Assign stable entity IDs and base revisions; commit incoming changes and sync state consistently. Resolve non-overlapping changes only when the merge preserves document structure. Concurrent edits to the same chapter, reorder/delete conflicts and annotation anchors must preserve both versions until explicitly resolved. Never apply last-writer-wins to an entire manuscript. Large initial downloads need resumable progress and usable already-downloaded books.

Do not sync access tokens/API keys, device paths, file grants, caches or transient cursor state as manuscript records. Define explicitly which preferences are shared and which are device-specific. Account changes/sign-out pause replication, segregate account state and preserve recoverable local edits; never upload one account's edits into another automatically. Surface quota exhaustion, unavailable account, network errors and paused uploads. Sync is not backup: keep independent history/recovery and deletion retention.

For iCloud Drive document operations, use Apple's security-scoped access and coordinated reads/writes, with file-presenter/version notifications as needed. Do not point the existing multi-file transaction store at an iCloud directory and assume the transaction replicates atomically. Provider access and synchronization require separate failure handling.

Apple app IDs must share an authorized iCloud container under the chosen developer team, with correct entitlements/provisioning. Development and production CloudKit schemas/environments need a controlled release path. Current ad-hoc CI app signing is insufficient evidence of working iCloud integration. This milestone will need developer-team/container access and signed builds; draft adapter work and fake tests can proceed before those credentials are available.

Acceptance: edit offline on each device and reconcile on reconnect; concurrent edits on two devices; app termination mid-transfer; account switching; quota exhaustion; local-only usage; initial library download; deleted/renamed chapters; attachment transfer; no lost formatting or Neo metadata. Validate on actual Mac, iPhone and iPad signed builds. Simulator/mock success alone does not establish working iCloud support.

## Service contracts

| Service | Contract and ownership |
| --- | --- |
| Spellchecking | Check an immutable text snapshot with language and document revision; return UTF-16 ranges and replacement candidates, not just unique words. Discard stale results. Expose supported languages and dictionary availability; distinguish ignore-for-session from persistent learning. |
| Secret storage | Read/write/delete with outcomes for not found, locked, denied, unavailable, and failure. Never convert an error to an empty valid key. No plaintext persistence fallback; offer explicit session-only use if the vault is absent. |
| Document access | Pick/open/create documents using an opaque `DocumentHandle` with display name, capabilities and permission lifetime. Expose read/write streams or staged files; never require QML to resolve a URI to a local path. Cancellation is normal. |
| Sharing | Accept a share intent (general share versus compose email), subject/body and staged attachments. Report presented, cancelled, unavailable or failed as far as the OS permits. Presentation is not proof of sending. Retain attachments until the provider no longer needs access. |
| Lifecycle | Normalize activation, suspension, foreground restoration, open-document requests and memory pressure. Trigger bounded saves; foreground reconciliation rechecks permissions and external changes. |
| Storage locations | Choose working library, settings, cache, recovery and export-staging locations with Qt defaults and target policy. Existing desktop libraries must not move silently. |
| Platform capabilities | Describe actual available operations and reasons, including provider/language availability. QML shows enabled actions with useful explanations; OS identity alone is not a capability. |

Use QObject signals/request IDs or a consistent Qt asynchronous job API. Define cancellation, exactly-once completion, owner lifetime, and callback thread in the contract. Native UI calls run on the appropriate UI thread; platform workers observe their SDK's thread/apartment requirements. Do not assume all native calls are thread-safe.

One composition root in `main.cpp` constructs adapters and passes them to application services. Start by wrapping the existing macOS behavior; do not introduce a global service locator or a giant virtual `Platform` class. Use a Qt-compatible typed result initially; adopt `std::expected` only after all selected standard libraries pass the toolchain probe.

## Platform mapping to validate

| Capability | macOS | Windows | Linux | iOS/iPadOS | Android |
| --- | --- | --- | --- | --- | --- |
| Spelling | NSSpellChecker | Windows ISpellChecker | Evaluate Enchant/Hunspell, installed dictionaries and licensing | UITextChecker, validate integration with Qt input | Evaluate system TextServicesManager/SpellCheckerSession availability; Qt IME composition testing |
| Secrets | Keychain | Credential Manager Win32 generic credentials | Secret Service via a maintained integration; handle locked/absent vault | Keychain with intentional accessibility policy | Encrypt stored secret with a key protected by Android Keystore; Keystore is not arbitrary-string storage |
| Files | Qt native picker; security-scoped access if sandboxed | Qt native picker | Qt picker/desktop portal, validate sandbox deployment | Document picker and security-scoped access; coordinate provider writes | Storage Access Framework, content URIs and persistable grants |
| Sharing | NSSharingService | Prototype desktop share interop and attachment support; expose export fallback when unavailable | Email portal where supported; validate installed backend/client | Activity sheet; dedicated mail composer only if available | Sharesheet with granted content-URI attachment access |
| Lifecycle | App activation and open-document events | Activation and file association | Desktop activation and file association | Scene/background/foreground and permission restoration | Activity/process recreation, pause/resume, revoked grants |

These are implementation candidates, not confirmed equivalent behaviors. Spelling providers and sharing clients differ; the application contract must make those differences visible. Do not promise attached email through a generic `mailto:` URL.

## Storage and data safety

1. Keep the existing Neo-compatible local library representation and journal/atomic-write behavior. Add schema/version migration and cross-platform path validation independently of the native adapters.
2. Use an app-managed working library on mobile. Import or explicitly publish copies through document providers initially. Distinguish “saved locally” from “exported to provider”; do not label this live synchronization.
3. A future linked external library needs base revisions, provider change detection, interrupted-transfer recovery and explicit conflict handling. A QLockFile does not coordinate two devices or make a remote provider transactional.
4. Retain opaque grants/bookmarks separately from manuscript content. Reacquire expired/revoked access without losing edits. Test unavailable cloud files and offline operation.
5. Normalize generated IDs and validate Windows reserved names, forbidden characters, trailing spaces/dots, path length, Unicode normalization and case collisions in imported archives. Add size limits and symlink tests without changing user text.
6. Move expensive export/backup work off the editor thread using immutable snapshots. QTextDocument remains on its owner thread; use a separate worker-owned document where appropriate, after validating rendering/font constraints.
7. Save continuously and journal recovery data; a background callback cannot guarantee enough time to finish a large save before mobile process termination.

## UI, commands and distribution

Extract `BookGrid`, `ChapterList`, `ManuscriptEditor`, `Inspector`, `Theme` and command models. Desktop retains menus, shortcuts and resizable panes. Mobile uses navigation stacks/sheets, safe areas, touch-sized actions, keyboard avoidance, rotation and tablet split layouts. Layout responds to available space and input method, not only the OS name.

Use QKeySequence/StandardKey where available and a centralized mapping for app-specific actions. Validate Command versus Control, Return/Enter, IME composition, dead keys, emoji, RTL text, selection handles and hardware keyboards. Test VoiceOver, Windows screen readers and Linux accessibility. Avoid theme colors that fight native controls. Qt rendering is native application code, but not every Qt Quick control is an OS-owned widget.

Bundle fonts only after license review; use tested platform fallbacks. Format fixtures should test content/structure; screenshot baselines should be per-platform rather than requiring identical font rasterization.

Select CMake implementations with explicit Windows/macOS/Linux/iOS/Android branches. Keep tests optional and Qt Test a test-only dependency. Provide CMake presets, pinned dependency inputs and a small C++23 feature probe. Build Qt host tools separately from cross-compiled target artifacts when required. Align the minimum Qt version with the tested release and its security updates before shipping.

Release policy is separate from OS adapters: macOS signing/notarization, Windows signing/installer, Linux package and sandbox choices, and iOS/Android store signing each need their own jobs. Store-distributed mobile updates use the store. Do not add a universal self-updater. Include Qt/third-party license notices and review static/mobile distribution obligations before release.

## Ordered implementation work

| Step | Scope | Completion evidence |
| --- | --- | --- |
| 1 — during macOS parity | Define contracts; inject existing Mac spelling/secrets/sharing; replace silent stubs; separate Apple targets | Same Mac workflows and screenshots pass; fake-service tests cover failure and cancellation; non-Mac operations report unavailable honestly |
| 2 — during macOS parity | Extract library/editor/import-export services and commands; introduce document handles and staging | Existing local libraries open without migration surprises; export failure preserves edits; no native imports in shared targets |
| 3 — desktop build checks | Windows MSVC and Linux GCC build/test jobs, then Clang coverage; quality checks on each commit and CI | C++23 feature probe, core tests and per-platform UI smoke/screenshots pass; still no support claim before adapter acceptance |
| 4 — after macOS acceptance | Windows and Linux adapters, packaging, desktop polish | Install/open/save/reopen/import/export/spell/share/credentials pass on clean systems, including missing providers and non-ASCII paths |
| 5a — Apple sync foundation | Prototype signed CloudKit integration and shared revision/conflict contracts; add iCloud sections/states to Mac home | Two signed Apple clients converge after offline edits; conflicts preserve both versions; account/quota failures are visible |
| 5 — mobile feasibility | iOS simulator and Android emulator vertical slice using disposable fixtures | Open -> edit -> save -> background/kill -> restore -> export; permission revocation and hardware/soft keyboard tests pass; validate rich-text editing early |
| 6 — mobile implementation | Distinct phone/tablet homes, native adapters, Apple iCloud integration and relevant feature parity | Real iPhone/iPad/Android acceptance, accessibility, offline/recovery and large-manuscript measurements; signed distribution pipeline |

Mac parity remains the release gate for step 4. Apple sync contract design begins during steps 1–2; its signed prototype can run after the local storage/revision foundation is stable and does not have to wait for Windows/Linux release completion. Lightweight build checks can run earlier to prevent avoidable portability regressions. No calendar estimate is justified until the mobile document/IME slice is validated.

## Test and acceptance matrix

- Shared: identical Neo fixtures across systems; Unicode and rich formatting; chapter/revision invariants; crash replay; external conflict; format round trips and independent readers.
- Contract: unavailable spell language, locked vault, denied access, user cancellation, provider disconnect, stale async result and destroyed request owner.
- Desktop: clean installation, read-only paths, non-ASCII user directories, different DPI, light/dark controls, Wayland and X11 for the chosen Linux distributions.
- Mobile: low memory, process death between edits and flush, denied/revoked file grants, offline provider, rotation/split view, IME composition and keyboard obscuring the cursor.
- Performance: matched manuscripts and scenarios; startup, typing latency, scrolling, import/export, peak memory. Set budgets after measurements, not unsupported speedup claims.
- CI: preserve required formatting/lint before every commit and in CI. Publish test logs and screenshots; do not call offscreen rendering a substitute for real native integration tests.

## Open choices for later milestones

Support-floor OS versions and CPU architectures, first Linux packaging format/distributions, Intel Mac release support, vault/spelling integration dependencies, and the exact mobile feature surface remain decisions to validate. Initial recommendation: desktop Windows x64 and Linux x64, mobile ARM64 plus simulator/emulator targets; expand architecture coverage after CI and Qt/toolchain support are proven. This does not exclude future ARM Windows/Linux builds.

## Primary references checked

- [Qt 6.10 supported platforms](https://doc.qt.io/qt-6.10/supported-platforms.html): use the tested compiler/SDK matrix; Qt support alone does not establish Neon support.
- [Windows ISpellChecker](https://learn.microsoft.com/en-us/windows/win32/api/spellcheck/nn-spellcheck-ispellchecker)
- [Windows CredWriteW](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew)
- [Apple document directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [Apple UITextChecker](https://developer.apple.com/documentation/uikit/uitextchecker)
- [Android document access](https://developer.android.com/training/data-storage/shared/documents-files)
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore)
- [Secret Service specification](https://specifications.freedesktop.org/secret-service/latest/): latest page currently presents a draft; implement against deployed stable provider capabilities, not draft-only features.
- [XDG FileChooser portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.FileChooser.html)
- [XDG Email portal](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.Email.html)

Additional Apple primary references:

- [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9?language=objc)
- [Apple CloudKit sync example](https://github.com/apple/sample-cloudkit-sync-engine)
- [Configuring iCloud services](https://developer.apple.com/documentation/xcode/configuring-icloud-services)
- [UIDocument conflict handling](https://developer.apple.com/documentation/uikit/uidocument)
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)
