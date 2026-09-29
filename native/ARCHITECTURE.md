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
an explicit section-sidebar toggle to hide/show the sidebar. Focus mode retains the
selected section and unsaved editing state. Typography sheets follow appearance.

Shared colors and bundled OFL fonts live in EditorialTheme and resources/fonts.
Only real implemented actions appear in the UI; sync/review controls will arrive
with their workflows. CI captures real native light/dark editor and library views.

## Presets and history

The portable preset catalog defines Book, Research Paper, Newsletter, Essay, and Meeting
Notes outlines, vocabulary, section roles, and reading defaults. Schema 3 stores the
preset identifier and each section role; titles can change without losing meaning.
Reading defaults are projected into native paragraph styles, not rich-text export.

The Foundation adapter stores local history inside the same atomic JSON envelope as
the current draft. Changed saves add a full snapshot at most once per minute; named
checkpoints capture exact drafts. Project-wide restore validates identity, preserves
the current draft in a checkpoint, increments the current revision, and writes the
restored content and both history entries together before changing in-memory state.
Failed writes/conflicts retain the original draft. Snapshots exclude nested history.

Schema 1/2 originals receive byte-for-byte migration backups; all history travels
inside the project through Trash and restore. Duplicates retain content/roles with
new identities and independent history. Unknown schemas, malformed history, and
foreign-project snapshots are rejected. No automatic retention/deletion is performed.
Large-file scaling, asynchronous storage, coordinated writes, diff views, and scoped
restore remain later work. The history UI is a local project browser, not sync or undo.
