# Native preview parity verification

Reference: `approved-preview.html` is unchanged. The final rendered CSS cascade, rather than intermediate Figma variants or earlier CSS declarations, supplies the dimensions in the platform audits. The latest user instruction overrides glass styling on History Back: that action remains unboxed.

## Comparison method

Read-only browser inspection exported computed rectangles, font declarations, colors, borders, padding, margins, and shadows for Library, editor, creation, Settings, and History at Mac, 390, 1024, 768, 507, and 335 widths. Local measurement artifacts are in the project-level `outputs/neon-native-parity-audit` directory. Settings and History are overlays, so their exports also contain the underlying workspace; use their page classes when comparing.

`native/uitests/Fixtures.json` now has an `approved-preview` variant and preference profile. It reproduces the three sample chapter titles and paragraphs and three library projects without changing existing test variants or any user manuscript. The size preference is deliberately unset so production responsive defaults apply.

Control-by-control changes are recorded in `macos-preview-parity.md`, `history-settings-parity.md`, and `ios-preview-parity.md`. Native persisted-status wording replaces preview-only claims. Extra existing commands remain reachable through menus, context actions, accessibility actions, or Advanced preferences.

## Appearance switching

Glass backgrounds retain view identity across layout and appearance updates. A single window-level appearance owner replaces repeated child-controller assignments. Both platforms use a 160 ms crossfade without translation; Reduce Motion skips it. Rapid changes remove the prior overlay, and overlays do not intercept input. Settings updates its controls in place; editor content, selection, and window size are preserved.

Regressions cover glass identity, appearance toggles, preserved editor state, fixed window geometry, history persistence and cancellation, adaptive layout, and isolated preferences. Visual captures complement those tests; passing tests alone does not establish visual parity.

## Platform boundaries

Native AppKit/UIKit text rasterization, system window controls, safe areas, keyboards, menus, and actual Liquid Glass rendering remain platform surfaces. Simulated native 507/335-point containers validate narrow layouts but do not establish real OS Split View behavior. No claim of identical raster output or physical-device testing is made.

## Verified results for this correction pass

- Mac: all 20 CTest tests passed, including `native_ui` (17.53 seconds), manuscript persistence, controls, History/Settings and window-layout checks. The subsequent relative-date label adjustment passed the Library controller regression again.
- Source weights were independently inspected through CoreText: Source Sans 3 and Literata regular styles use weight 400. No artificial weight compensation was introduced.
- Same-content Mac captures: `approved-library.png`, `approved-editor.png`, `approved-checkpoint.png` in `/private/tmp/neon-quiet-build`. These were inspected alongside the reference; macOS recording/traffic-light chrome is outside the content specimen.
- Same-content UIKit captures: `/private/tmp/neon-approved-ios-viewports/approved-{390,1024,768,507,335}-{library,reopen,navigation,picker,history,settings}.png`. These are isolated native viewport containers. The final mobile audit records exact interaction-suite results.

- iPhone recorded journey passed; the final isolated iPad recorded journey passed (1 test, 0 failures, 65.718 seconds). The first iPad attempt timed out waiting for animation quiescence; its app stack was idle, and the isolated retry used unchanged assertions. Both device families previously passed controls checks, and actual iPad rotation passed.
- The latest same-content capture run had 25 route passes and five picker assertion failures caused by testing UILabel’s permitted line count rather than the rendered line count. The corrected bounded 335-point picker/Settings checks pass and confirm actual attributed Source Sans 15, single-line layout, rapid appearance toggles, and typing-state preservation. This is not reported as a fresh 30-of-30 run.
- Final formatting, lint, dependency checks and `git diff --check` pass.

## PR review follow-up (2026-10-26)

The hosted Mac walkthrough still expected removed chapter ellipsis buttons, the old right-aligned sidebar toggle, an obsolete History empty-state string, and always-visible Settings search. It now verifies the replacement chapter context menu and current navigation while retaining editing, persistence, undo, and redo assertions.

Parallel review found and corrected:

- Standards/correctness: menu-bar Project actions passed an NSMenuItem where the popover required a view anchor. The smoke now dispatches the installed menu command.
- Spec: Mac blank-separator layout formatting leaked into new typing. A real AppKit selection/insertion regression failed before normalization and passes after it; IME composition remains protected.
- Spec: wide iPad Settings displayed the compact 17pt default while the manuscript used 19pt. Both now share viewport-aware resolution, preserving explicit preferences and leaving defaults unset.
- Additional validation: Settings header/footer child frames did not follow UITableView resizing. A 335→1024→335 regression now verifies the contents as well as the outer containers.
- Copilot: corrected two comment spacing nits and removed a redundant nested condition. No functional Copilot findings remained.

Local validation: all 20 Mac/core tests pass; native Mac and iOS builds, pinned quality checks, and the iPad Settings regression pass. The recorded Mac XCTest driver compiles locally but is killed before bootstrap on this host; the hosted Mac job is the authoritative recorded-walkthrough verification for this correction.
