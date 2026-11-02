# Native implementation of the approved preview

The design reference is [the approved interactive preview](approved-preview.html). Native code implements its Refined / Unified workspace, Quiet sans navigation, and Paper glide direction.

## Screens and behavior

- Library: compact heading/actions row, no home toolbar app title, square contiguous sidebar rows.
- Editor: Source Sans navigation, Literata manuscript, pane-aligned breadcrumb, full-width hover/selection and Settings, preset-aware add action immediately below the section list.
- New project: dedicated six-preset page with structural descriptions, Continue, and real project creation.
- History: saved revisions, filters, chapter-aware read/compare/details, optional checkpoint notes, and restore that preserves the working draft first.
- Settings: appearance, writing, automatic checkpoints, motion and transparency preferences. Disabling automatic checkpoints does not disable document saving.
- iPhone and narrow iPad: overlay navigation and responsive content. Standard iPad retains a sidebar. Project, chapter, Library-return and sidebar transitions have separate timings and respect Reduce Motion.
- Liquid Glass uses native supported APIs with opaque fallback for older systems or reduced transparency.

## Storage and compatibility

Existing documents and history without notes remain readable. Nonempty checkpoint notes add an optional `note` member to history entries; older builds with strict history validation will refuse such files rather than discard notes. Empty notes retain the previous entry shape. The current build preserves notes, Unicode content and IDs across reopen; failed/conflicted restores leave the draft and on-disk file unchanged.

## Initial implementation verification

The subsequent measured correction pass is documented in [visual parity verification](visual-parity-verification.md). The results below describe the initial implementation, before that correction pass.

- macOS and iOS simulator builds succeed.
- All 19 shared/core/controller CTest checks pass, including new History/Settings geometry and persistence cases. The separate Mac native UI smoke also passes, including real preset creation/reopen and screenshot capture.
- iPhone controls and recorded editor journey pass. The 13-inch iPad controls, actual portrait/landscape sidebar regression, and recorded editor journey pass.
- All 24 native viewport checks pass: Library, editor, navigation, creation, History and Settings at 335, 507, 768 and 1024 points. Screenshots were inspected and clipping, wrapping, footer and contrast defects corrected.
- Pinned formatting, lint and dependency checks pass.
- The separate Mac recorded XCTest driver builds, but its runner was killed before bootstrap; no passing Mac recorded journey is claimed. Its diagnostics are retained separately from passing native smoke evidence.
- Half/third-width iPad captures use isolated native containers, not actual OS Split View. Physical devices and current-head remote CI remain unverified. No universal pixel-perfect claim is made.
