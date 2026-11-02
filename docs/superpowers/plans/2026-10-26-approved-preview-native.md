# Approved Preview Native Implementation Plan

> **For agentic workers:** Use parallel platform owners with root integration. User has approved the preview and explicitly requested implementation.

**Goal:** Translate the approved Refined Unified workspace preview into native macOS and iOS/iPadOS screens with real persistence.
**Architecture:** Keep AppKit/UIKit controllers and portable C++ document model. Share typography, preference handling and history snapshots in Apple adapters. Preserve current manuscript editing and storage contracts.
**Tech Stack:** Objective-C++, AppKit, UIKit, C++23, Core Animation.
**Spec:** `../../design/approved-preview.html` (approved live preview; snapshot of latest design copied to docs/design below).

## Global constraints
- Quiet sans navigation: Source Sans 3. Literata manuscript and display headings.
- Contiguous full-width square chapter selection/hover and Settings rows. Preset-aware add action below list.
- Consistent panel background, 56pt toolbar, no Neon toolbar title on home Library; breadcrumb after sidebar; compact collapsed layout.
- Project open440ms, chapter260ms (only manuscript), Library380ms, sidebar280ms. Respect Reduce Motion.
- iPhone and narrow iPad <=600 points use overlay sidebar; full iPad keeps sidebar. No wrapping Library breadcrumb.
- Settings controls must change actual native preferences. Real checkpoints/restore preserve current draft before restoring.
- Preserve manuscripts and test isolation; no synced sources edits.

## Review focus
- Long titles and narrow335pt windows must truncate/wrap appropriately without obscuring controls.
- IME editing, selection, undo and scroll position survive navigation.
- Restore failures must not mutate live content or lose the before-restore checkpoint.
- Accessibility reduced motion/transparency override custom effects.
- Old saved projects and history without notes remain readable.

## Tasks
- [x] Shared design: NeonUI/NeonUISemibold, native glass backdrop helper, accessibility preferences, square row fills, default manuscript measure.
- [x] Mac: toolbar/sidebar/library/editor spacing, action-specific motion, dedicated preset creation screen.
- [x] iOS/iPadOS: adaptive navigation, library/editor/preset screen parity and motion.
- [x] History/Settings: structured revision/working snapshots, checkpoint notes, full history read/compare/details, adaptive layout and functional settings.
- [x] Preset catalog: Article and Blank document plus labels and persistence tests.
- [x] Validate: native/scripts/quality.py, portable/session/UI tests; build both platforms; simulator screenshots for compact/full/split widths; inspect actual output against preview.
- [x] Review integrated diff and document verified and unverified boundaries. Delivery targets existing PR #9.

Verification limits and results: [native implementation notes](../../design/native-preview-implementation.md).
