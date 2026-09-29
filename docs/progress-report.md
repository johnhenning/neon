# Neon macOS implementation report

Report date: 2026-09-29. Feature inventory v1; pinned Neo reference `285c081065224aedb4e8c21c5d99f08ed616d217`.

## Progress count

**17 implemented / 80 total (21.2%); 40 partial; 23 missing.**

This is a code-level implementation inventory, not a percentage of engineering effort or a release-readiness score. A row counts as implemented when its described user-facing behavior is wired in the current app with no known missing subfeature. It does not mean full independent acceptance testing. Partial rows count as zero in the implemented numerator. The evidence column explicitly records unverified workflows. Current macOS 26 run `36532921107` passed formatting/lint, 12 core test cases, 3 controller regression cases and the UI smoke test; app packaging completed. This is targeted evidence, not full manual acceptance.

The denominator is the 80-workflow scope audited from Neo README, TUTORIAL.md, app.js and main.js, not a feature count published by Neo. It is versioned so additions or regrouping cannot silently change the percentage. See the complete [CSV scorecard](feature-scorecard.csv). iCloud, Git/history, other platforms, and new settings UX are tracked separately as Neon extensions; none are counted as Neo parity.

| Area | Implemented | Partial | Missing | Total |
| --- | ---: | ---: | ---: | ---: |
| Library | 5 | 2 | 5 | 12 |
| Writing | 3 | 7 | 5 | 15 |
| Typography and focus | 1 | 4 | 5 | 10 |
| Planning and revision | 2 | 4 | 2 | 8 |
| Search and spelling | 1 | 3 | 0 | 4 |
| Goals | 1 | 4 | 0 | 5 |
| Covers | 1 | 3 | 3 | 7 |
| Import and export | 1 | 9 | 1 | 11 |
| Persistence and delivery | 2 | 4 | 2 | 8 |

## Current build and latest changes

- Existing macOS 26 / Qt 6.10.3 preview builds and packages successfully. The last completed pre-change run passed 12 core test cases plus UI smoke (Qt also reports setup/cleanup as two additional passes).
- Already submitted before the request to pause features: native macOS control style and system appearance; whole-manuscript find/replace; single-step split undo fix; safe opening of empty Neo chapter lists. Three controller regression scenarios were added. These are in draft PR #1, not merged. All three new controller regression scenarios passed.
- The current render is an actual application capture. Native control rendering and system colors are being checked, not a claim of a full AppKit or Liquid Glass redesign.
- Further feature implementation is paused for review. Settings below are a proposal, not an implemented screen.

## Material limitations

The editor still shows one selected chapter, lacks Neo’s Enter x2/x3 behavior, smart punctuation, drop caps, structured ghost outlines and full focus modes. Rich-text round trips can lose custom Neo annotations. Undo remains split between text and structural histories. Export fidelity needs independent DOCX/EPUB/PDF validation. Daily backup scheduling and restore UX are unfinished. No measured performance advantage is claimed. Use disposable manuscript copies for acceptance testing.

## Additional Neon scope

| Extension | State |
| --- | --- |
| Native macOS styling | Build and light/dark render passed; full window chrome captured |
| Non-destructive Neo library copy | Prototype; custom markup fidelity remains a blocker |
| Platform-specific home screens and service contracts | Planned |
| macOS/iPhone/iPad iCloud library sync | Planned; no CloudKit implementation |
| Local durable version history and Git | Planned; no backend |
| Windows/Linux/iOS/Android releases | Not validated or packaged |
| Comprehensive settings design | Proposed in settings-design.md |
| Signing/notarization and distribution | Ad-hoc preview only |

## Recommended next implementation slices after review

1. Manuscript fidelity and editing safety: preserve Neo custom markup and metadata, coordinate undo, validate save/reopen and recovery.
2. Core writing parity: Enter gestures, smart punctuation, poetry, continuous manuscript and drop caps.
3. Settings shell and typography preview after approval; finish readable native controls and keyboard navigation.
4. Planning/revision, goals and backup scheduling; independent export validation.
5. Remaining library/covers/locales/updater workflows; acceptance audit and matched performance measurements.

## Full inventory

| ID | Feature | Status | Evidence / remaining gap |
| --- | --- | --- | --- |
| NEO-001 | First-run author and pantser/plotter setup | Missing | No first-run flow |
| NEO-002 | Create and open books | Implemented | Sample library exercised by UI smoke |
| NEO-003 | Edit title author subtitle and series | Implemented | Code reviewed; title/author smoke-tested |
| NEO-004 | Create shelves | Implemented | Code reviewed; interactive acceptance pending |
| NEO-005 | Rename shelves | Implemented | Long-press action; interactive acceptance pending |
| NEO-006 | Delete shelves safely | Missing | No action |
| NEO-007 | Reorder shelves | Missing | No drag/reorder action |
| NEO-008 | Reorder and move books by drag and drop | Partial | Move-to-shelf action exists; no drag/order parity |
| NEO-009 | Remove from shelf and reshelve | Partial | Removal exists; unshelved discovery needs acceptance |
| NEO-010 | Trash books with recovery through OS trash | Missing | No trash action |
| NEO-011 | Pen names and author-specific shelves | Missing | Default author only |
| NEO-012 | Word-goal progress on book covers | Implemented | Goal property and progress control; sampled in smoke |
| NEO-013 | Continuous manuscript with title page | Missing | Single selected chapter only |
| NEO-014 | Rich-text typing bold and italic | Implemented | Qt document implementation; full keyboard acceptance pending |
| NEO-015 | Paragraph alignment | Implemented | Four alignments wired in Format menu; acceptance pending |
| NEO-016 | Create and rename chapters | Implemented | UI/controller implemented; creation used in tests |
| NEO-017 | Automatic chapter numbering including single-chapter exception | Partial | Fallback chapter numbers; no single-chapter/title-page rule |
| NEO-018 | Reorder chapters | Partial | Arrow commands; no drag workflow |
| NEO-019 | Split and merge chapters | Partial | Implemented; split regression test added; annotation/merge cases remain |
| NEO-020 | Double/triple Enter scene and chapter creation | Missing | Explicit commands only |
| NEO-021 | Scene-break insertion and deletion behavior | Partial | Insertion command; upstream deletion rules absent |
| NEO-022 | Poetry paragraphs and Shift-Enter behavior | Partial | Indent/italic toggle; special enter/backspace behavior incomplete |
| NEO-023 | Smart dashes ellipses and quotation marks | Missing | No transform engine |
| NEO-024 | Language-aware French spacing and punctuation | Missing | No language typography handling |
| NEO-025 | Tab spacing and safe cross-boundary editing | Missing | No equivalent boundary logic |
| NEO-026 | Unified text and structural undo/redo | Partial | Separate stacks; split fix tested this build; unified chronology absent |
| NEO-027 | Rich paste cleanup with formatting preservation | Partial | Qt paste; Neo annotation-preserving codec absent |
| NEO-028 | Light and dark page appearance | Implemented | Both captured; macOS native theme refresh in current build |
| NEO-029 | Curated body font choices and installed-font preview | Partial | Unfiltered installed families; no preview or reliable current selection |
| NEO-030 | Drop caps with literary fantasy sci-fi and none | Missing | No drop-cap rendering |
| NEO-031 | Font size and page zoom | Partial | Font-size setting; no equivalent whole-page/pinch zoom |
| NEO-032 | Distraction-free fading controls and bright UI option | Partial | Hide-controls mode; no fading/bright option |
| NEO-033 | Edge-reveal and pinned chapter/notes panels | Missing | Static sidebar only |
| NEO-034 | Typewriter scrolling | Partial | Cursor positioning exists; limits and persistence unverified |
| NEO-035 | Paragraph focus | Missing | No dimming engine |
| NEO-036 | Sentence focus | Missing | No sentence highlighting |
| NEO-037 | Fullscreen and complete shortcut help | Missing | Focus hides controls; no fullscreen/help sheet |
| NEO-038 | Book notes and outline documents | Implemented | Separate persisted documents; interactive acceptance pending |
| NEO-039 | Chapter notes in navigation | Implemented | Persisted chapterNotes and editable fields |
| NEO-040 | Structured chapter/section outline and ghost paragraphs | Missing | Free-form outline only |
| NEO-041 | Custom tab names | Missing | Fixed labels |
| NEO-042 | Move passages into Darlings | Partial | Keyboard/menu capture; no drag/drop; undo incomplete |
| NEO-043 | Restore Darlings to original location | Partial | Context anchors; ambiguity and edited-anchor tests missing |
| NEO-044 | Insert placeholder with linked sticky note | Partial | Visible TODO text; not Neo marker semantics |
| NEO-045 | Resolve navigate and reconcile placeholders | Partial | Resolve and chapter flags; exact navigation/deletion reconciliation incomplete |
| NEO-046 | Whole-manuscript find previous/next and match highlights | Partial | Whole-book navigation added; all-match highlighting/count missing |
| NEO-047 | Replace current/all across manuscript | Implemented | New controller test covers case-insensitive whole-book replace and undo; CI passed |
| NEO-048 | On-demand spelling with inline marks | Partial | Native word list; no inline squiggles |
| NEO-049 | Spelling suggestions ignore learn and language choice | Partial | Native suggestions/learn; ignore and persistence incomplete |
| NEO-050 | Book/chapter word counts and toggle | Partial | Counts exist; total/current toggle absent |
| NEO-051 | Book word goal | Implemented | Metadata and goal dialog; code reviewed |
| NEO-052 | Daily goal and writing-day boundary | Partial | Counts/settings; midnight timer and rollover testing missing |
| NEO-053 | Word sprint start stop and feedback | Partial | Basic target counter; acceptance and completion behavior incomplete |
| NEO-054 | Thirty-day progress chart | Partial | Bars exist; upstream target/cumulative presentation incomplete |
| NEO-055 | Six seeded art styles | Partial | Colored geometric cover; not six styles |
| NEO-056 | Six type templates and bundled cover fonts | Missing | One Georgia title layout |
| NEO-057 | Reroll seeded design | Partial | Seed changes palette; full typography/art variation missing |
| NEO-058 | Import/drop custom cover art | Partial | Picker and image conversion; no drop action |
| NEO-059 | Opt-in AI cover generation and progress | Missing | Explicitly disabled placeholder |
| NEO-060 | Painted/seeded mode switching and regeneration | Missing | No AI pipeline |
| NEO-061 | Secure cover API-key storage | Implemented | macOS Keychain code; signed/native interactive acceptance pending |
| NEO-062 | TXT manuscript import with chapter/scene detection | Partial | Parser exists; realistic fixture validation pending |
| NEO-063 | Markdown manuscript import | Partial | Heading/emphasis fixture passes; title and scene fidelity incomplete |
| NEO-064 | DOCX manuscript import | Partial | Unicode/emphasis round trip; heading/style fidelity incomplete |
| NEO-065 | Plain-text export | Implemented | Serializer implemented; complete upstream comparison pending |
| NEO-066 | Markdown export | Partial | Basic output; formatting/poetry fidelity incomplete |
| NEO-067 | HTML export | Partial | Basic output; full style/annotation handling incomplete |
| NEO-068 | PDF export | Partial | PDF signature tested; pagination/font fidelity not independently checked |
| NEO-069 | DOCX export | Partial | Valid basic OOXML round trip; independent Word/style checks missing |
| NEO-070 | EPUB export with cover navigation and metadata | Partial | EPUB3/nav structure tested; cover and EPUBCheck missing |
| NEO-071 | Shelf anthology export | Missing | No anthology path |
| NEO-072 | Email timestamped PDF and text fingerprint | Partial | Mac share handoff and hash; alternate email settings and acceptance missing |
| NEO-073 | Continuous autosave to plain files | Implemented | Atomic store and application saves exercised; failure testing remains |
| NEO-074 | Crash recovery and visible save errors | Partial | Journal replay test passes; UI kill/recovery acceptance incomplete |
| NEO-075 | Automatic daily ZIP backups and 14-day retention | Partial | Manual verified ZIP/retention; no automatic scheduler |
| NEO-076 | External-change refresh and conflict handling | Partial | Conflict copies; no automatic safe refresh workflow |
| NEO-077 | Library location and reveal workflow | Partial | CLI override; no complete native location UI |
| NEO-078 | Eight interface locales | Missing | English strings; no catalogs |
| NEO-079 | Update checks and installation flow | Missing | No updater |
| NEO-080 | About attribution and help links | Implemented | Neo attribution and license notices included |
