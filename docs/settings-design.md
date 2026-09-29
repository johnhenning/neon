# Neon settings and typography proposal

Status: for review, not implemented. 2026-09-29. macOS first; shares settings definitions with future platforms.

## Product approach

Open a dedicated, resizable macOS Settings window from **Neon → Settings…** with **Command-comma**. Use a searchable sidebar and one readable pane, grouped native controls, short descriptions, and per-section “More options” disclosures. Keep roughly 4–6 commonly used controls visible per section. Avoid a long scrolling form, a modal wizard, and a single giant Advanced page.

The editor keeps quick controls for font/zoom/focus; those link to the relevant settings pane. Book metadata, goals, chapter structure, export recipes and Git actions remain contextual to the book. They are not all application preferences.

Native appearance: system UI font and controls, system accent color, standard keyboard navigation and focus rings. Application appearance follows macOS by default; explicit Light/Dark choices remain available. Manuscript typography can differ from the surrounding UI. This is a Qt macOS-style application; it is not a promise that every custom sidebar or card is an AppKit widget.

## Proposed navigation and controls

| Section | Visible by default | More options / contextual detail |
| --- | --- | --- |
| General | Startup destination (Library / Continue last book), default author, interface language, new-book writing style (Start writing / Outline first) | Reopen windows, default new-book template, shortcut reference; pen-name management opens library author controls |
| Writing | Body font with sample, text size, comfortable page width, focus mode (Off / Paragraph / Sentence), typewriter mode | Line spacing, paragraph spacing/indent, drop-cap style, smart punctuation and locale rules, poetry defaults, preferred view zoom |
| Appearance | Follow system / Light / Dark, page surface (Follow app / Paper), control visibility (Always / Fade while writing), reading-layout preview | Sidebar density, reduced motion preference that respects OS accessibility, fine page margins; avoid overriding OS UI scaling or accent by default |
| Library & Recovery | Library location, last successful save/backup, automatic-backup status, open backups, restore action | Backup destination, daily retention, recovery disk use, external-change behavior, move-library guided workflow; never a casual destructive path text field |
| Spelling | Writing language, on-demand check preference, enabled dictionaries, learned words | Per-book language override, personal dictionary management, ignored-for-session list; no forced squiggles while drafting |
| Connections | Provider cards for supported integrations and connection state | iCloud account/sync controls when implemented; cover-art credentials and privacy; Git transport credentials when implemented. Details appear only after a provider is enabled |
| Shortcuts | Searchable actions with current bindings and category filters | Custom bindings after validation, conflict detection, reset category; preserve text-editing and system accessibility shortcuts |

Search is always available above the sidebar. It searches labels, descriptions and synonyms such as “autosave”, “dark”, “font”, “spellcheck”, “backup”, “cloud” and “API key”. Results show the section and setting, open the correct disclosure and focus the control. Show meaningful “no results” suggestions. Never surface credentials in results.

Start on the last-used pane, or General on first use. Keep sidebar ordering stable. Show one preview using the writer’s current paragraph (or a built-in sample when no book is open), rather than multiple competing previews. Screenshots of this proposed settings UI should be labeled mockups until the native screen is implemented.

## Keep these near the manuscript

- **Book Details:** title, subtitle, author/pen name, series, book goal, cover, writing language, optional typography override.
- **Progress:** daily target, writing-day boundary, sprint controls and chart. The Settings shortcut should not open Goals, as the current preview does.
- **Export dialog:** format, template, paper size, margins, export font, cover inclusion and chapter conventions. “Save as preset” avoids permanent global clutter.
- **History:** checkpoints, comparisons, restore, and Git commit/branch/remote actions once implemented.
- **Library location details:** local/iCloud/Git mode, actual availability, conflicts and pending operations. Per-project Git remotes are not global settings.

## Settings scope and behavior

Every setting has a typed ID, default, valid range, scope, migration version, capability requirement, search terms and change handler. Generate UI descriptions/search indexes from this registry rather than duplicating strings and validation throughout QML.

| Scope | Examples | Display and storage policy |
| --- | --- | --- |
| This device | Window state, appearance override, cache/backup paths, font fallback, credentials | “This Mac” badge when scope might be ambiguous; keep device paths and secrets out of library sync |
| Default for new books | Author, pantser/plotter mode, writing typography preset | Label explicitly; changing defaults does not silently reformat existing books |
| This book | Writing language, goals, optional typography override | In book inspector with “Use app default” action; preserve with manuscript metadata where appropriate |
| Export preset | Page size, margins, output typography | Separate from editor view; allow a preview before writing a file |
| Account/library | iCloud sync mode and allowed shared preferences | Make shared scope explicit; define opt-in preference sync after the CloudKit schema is approved |

Appearance and display preferences preview immediately and persist on deliberate selection. Font preview while browsing is temporary until chosen; Cancel restores the previous font. Each section offers “Restore defaults…” with a list of affected settings. No global Apply button is needed for ordinary controls.

Operations such as moving a library, deleting a learned dictionary, removing credentials or changing storage mode use an explicit action and meaningful confirmation showing the affected item. Show validation beside the control, preserve the last working value on failure, and provide retry where appropriate. Autosave should remain enabled by default; expose backup/recovery controls rather than encouraging accidental data loss through an easy disable switch.

Distinguish “saved locally”, “backup created” and “synced”. A settings change does not claim sync succeeded. Unavailable capabilities explain why: missing dictionary, disconnected vault, iCloud unavailable, unsupported provider. Do not fill shipping screens with enabled-looking placeholders for planned features.

Keyboard-only use, VoiceOver labels, focus order, high contrast and text-size scaling are acceptance requirements. Search focus must not get trapped by a modal. Large text should cause sensible wrapping, not clipped native controls. Reset actions do not change manuscript content.

## Font audit: what exists today

Source: pinned Neo `app.js` font definitions and `styles.css` font-face declarations; Neon `Controller::fontFamilies()` and current QML preferences.

| Use | Neo choices | Neon today |
| --- | --- | --- |
| macOS body text | Georgia, Palatino, Baskerville, Hoefler Text, Iowan Old Style | Defaults to requested Georgia; exposes all families returned by QFontDatabase |
| Windows body text | Georgia, Palatino, Baskerville, Cambria, Constantia | Not tested on Windows |
| Linux body text | Gelasio, TeX Gyre Pagella, Libre Baskerville, Alegreya, Source Serif Pro | No bundled font setup in Neon |
| Literary drop cap | Didot / Bodoni 72, then Georgia fallback | Not implemented |
| Fantasy drop cap | Apple Chancery / Snell Roundhand | Not implemented |
| Sci-fi drop cap | Futura / Avenir Next / Helvetica Neue | Not implemented |
| Cover type | Anton, Bebas Neue, Oswald, Abril Fatface, Playfair Display, Cinzel, Josefin Sans, Libre Baskerville (with selected weights/styles) | Georgia title and default UI family for author; full cover templates missing |
| UI text | System UI stack | Qt platform default; macOS native style now explicitly selected |

These are source-defined choices, not a guarantee that every family is installed on every Mac or mobile device. The current picker does not show curated previews, restore its selection reliably or clearly report fallback. New body choices should be queried on the actual target using QFontDatabase and missing fonts identified rather than silently presented as installed. Native UI uses the system font without bundling Apple's proprietary UI fonts.

## Proposed font picker

The Writing pane shows a compact row: **Georgia · 16 pt · Choose…**, followed by a live paragraph preview. “Choose…” opens a searchable native-styled sheet with two groups: **Recommended** and **All installed fonts**. Each family shows its own sample, supported regular/bold/italic styles and whether the current text needs fallback. Filter private/hidden/system-internal family names.

Recommended Mac starting set: the five Neo body choices, shown only when available. Add optional sans-serif and monospaced writing choices through the installed-font list; do not prescribe dozens of defaults. Keep UI font, manuscript font, drop-cap font, cover font and export font separate. Their roles should be named explicitly.

Store both the requested family and an explicit fallback policy. If another device lacks the chosen family, keep the preference and show “Using [fallback] on this device”; do not overwrite the original choice. Exports must state whether a font is embedded, substituted or left to the reader. Do not promise identical pagination across systems.

Bundled cross-platform font candidates can use Neo's open-font families after license/asset review; do not copy Apple or Microsoft fonts into the application. Preserve the relevant font licenses and use appropriate TTF/OTF assets for the native app. Check glyph coverage for the supported writing languages and test combining marks, emoji, RTL text and CJK fallback.

## Suggested delivery after review

1. Build the settings registry and native Settings window with General, Writing and Appearance. Fix Command-comma routing and current-value restoration. Keep existing data compatible.
2. Implement the curated font picker/live preview and scoped defaults. Test font fallback and distinguish display settings from manuscript formatting.
3. Add Library & Recovery and Spelling as their parity workflows become reliable; implement meaningful statuses and restore tests.
4. Add Connections and version-control details only as their backends work. Introduce custom shortcuts after the shared command registry is stable.

Approval should cover the navigation/scoping and font picker behavior before implementation. No new settings screen has been added in this reporting pass.
