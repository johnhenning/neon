# Native writing toolbar implementation plan

**Goal:** Ship the approved single toolbar, with real selection-based editing and no duplicate Add chapter action.

**Architecture:** Shared attributed-text formatting helpers provide inline traits, paragraph styles/lists and style-preserving refresh. AppKit/UIKit adapters own selection, undo, keyboard behavior, toolbar layout and session flushing. The adapter adds validated per-section RTF alongside plain text, including checkpoint snapshots.

**Tech stack:** Objective-C++, AppKit, UIKit, CoreText, existing document session and CTest/simulator smoke.

- [x] Implement/test shared formatting transformations: bold, italic, underline, body/headings, bullet/numbered lists, quote; preserve traits and paragraph formatting across typography refresh and RTF roundtrip.
- [x] Mac: single compact toolbar, preset-specific insertions, selection-state reflection, editor undo and empty-selection typing; preserve sidebar and breadcrumb layout.
- [x] iOS/iPad: same tools in existing chrome, compact overflow on narrow viewports (no second toolbar), retain selection while commands run, undo/persistence checks.
- [x] Context tools: real hyperlink insertion for article/newsletter/blank; LaTeX source insertion and citation text insertion for papers, citation for essays. Clearly label source insertion; do not imply equation rendering or bibliography management.
- [x] Verify app builds, native/core tests, simulator formatting smoke, preview screenshots; quality checks then push PR9.

Validation: shared engine, Mac formatting integration, persistence/history/core tests and iPhone/iPad formatting smoke pass. Mac screenshot-based UI validation remains blocked by the locked desktop; do not treat bounded tests as visual verification.
