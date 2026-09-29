# Apple architecture

The Qt-free C++23 core owns the ordered Project / Document / Section / text-block
model, validation, identity and semantic mutation commands. Native adapters own
filesystem locations, serialization, atomic replacement and rendering. AppKit and
UIKit use the same Foundation DocumentSession and LibraryStore adapters.

## Current slice

A library enumerates UUID-named project JSON files, sorted by modification time.
Project titles never become paths. Each project contains one document with one or
more sections; each section currently contains one plain-text block. The model
supports stable identities and creator/last-editor metadata; full rich text,
per-change provenance and arbitrary block projections remain work.

Both editors flush before switching projects or sections. Native text systems own
undo within the current section. A new editor resets that undo scope; it must not
apply text from a previous section to the newly selected one. Typography is an
app-level presentation preference and is not stored as document formatting.

Foundation validates files before editing, rejects unsupported content without
overwriting it, detects external file changes and retains drafts on save errors.
Atomic replacement is not a journaled transaction, cross-process coordination or
a backup. I/O currently runs synchronously for this small preview. Durable worker
storage, recovery-copy UI, schema extensions and multi-file assets remain open.

## Native surfaces

Mac: AppKit library/sidebar/editor, native menus and typography sheet. The former
RTF prototype stays in git history and its separate preview branch; the new app
uses Application Support/Neon Apple Preview and never loads the old library.

iPhone: Library → project sections → editor. iPad: adaptive split navigation with
an explicit Chapters toggle to hide/show the sidebar. Focus mode retains the
selected section and unsaved editing state. Typography sheets follow appearance.

Shared colors and bundled OFL fonts live in EditorialTheme and resources/fonts.
Only real implemented actions appear in the UI; sync/review controls will arrive
with their workflows. CI captures real native light/dark editor and library views.
