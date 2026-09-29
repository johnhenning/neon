# Neo feature parity status

Current detailed inventory: [17 implemented / 80 workflows; 40 partial; 23 missing](progress-report.md). See the [machine-readable scorecard](feature-scorecard.csv). Counts describe implementation, not full acceptance or effort completion.

Neon is inspired by Hugh Howey’s [Neo](https://github.com/hughhowey/neo). The behavioral reference is Neo commit `285c081065224aedb4e8c21c5d99f08ed616d217`. macOS desktop parity is the first release goal. This is a development preview, not a parity-complete release.

| Area | Current implementation | Remaining validation or implementation |
| --- | --- | --- |
| Library | Books, shelves, book metadata, moving books, imported cover images | Pen names, full ordering and removal workflows, all procedural cover styles |
| Editor | Rich text, chapter selection, split/merge/reorder, scene insertion, notes and outline | Continuous manuscript, original Enter behavior, smart punctuation, drop caps, complete poetry behavior |
| Revision | Text undo and structural snapshots, Darlings, TODO placeholders | Unified undo history, unambiguous anchor restoration, preservation of Neo custom markup |
| Focus | Distraction-free controls and typewriter option | Sentence/paragraph focus parity, keyboard and accessibility validation |
| Search and spelling | Whole-manuscript search/replace, macOS spelling bridge | All-match highlighting/counts, complete spelling UX |
| Goals | Word goals, daily counts, sprint UI | Date rollover, charts, full upstream behavior |
| Formats | TXT/Markdown/DOCX import; TXT/Markdown/HTML/PDF/DOCX/EPUB export | Independent app interoperability checks, style fidelity, covers, shelf anthologies |
| Persistence | Atomic files, transaction recovery, conflict copies, library lock, manual ZIP backups | Automatic daily backups, restore UI, external sync scenarios, large-library profiling |
| macOS | App bundle, spelling, Keychain, sharing bridge, CI screenshot capture | Signing/notarization, accessibility, real-device acceptance tests |
| Other | Neo license and inspiration notices | AI covers, eight locales, updater; other platforms follow macOS |

## Evidence

Core tests cover atomic storage, recovery, corrupt metadata, path traversal, ZIP integrity, text counting, basic format round trips, and PDF generation. The UI smoke test opens a populated temporary library and captures the bookshelf and editor. Successful tests establish only their covered behaviors.

No matched Neo/Neon performance benchmark has been completed. No performance improvement or full feature parity is claimed.
