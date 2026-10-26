# UIKit parity audit

Reference: final computed styles exported from `docs/design/approved-preview.html`, including all device layouts, in `outputs/neon-native-parity-audit`. Native implementation stays UIKit and preserves project storage/editing.

| Surface | Reference | Corrected native implementation |
|---|---|---|
| Chrome | 56 high; sidebar toggle28; main padding24 regular/4 compact | Explicit UIKit chrome replaces default navigation bar spacing; leading52 compact,24 regular,128 sidebar-hidden regular |
| Breadcrumb | Source14;32 high; separator12; gap8/6 | Single-line custom breadcrumb, fixed separator width, editable project title |
| History action | Source13 regular/12 compact;57.055/50.055 wide | Native text button with measured bounds; writing extras moved to long press/accessibility |
| Sidebar | 210 regular/260 compact overlay; top24 | Preserved native split/overlay behavior; compact overlay starts below chrome |
| Sidebar title/count | Source60016/22 and Source12/17.5; gap6 | Replaced oversized Literata heading; removed extra preset-name prefix |
| Chapter rows |44 high, Source14; selected600; accent12%; square fullwidth | Custom native rows; long-press context actions replace visible ellipsis; accessibility actions remain |
| Add section | Source13,47 high,6 top gap | Flat native row beneath list |
| Settings row | Source15,45.5 high,padding12/20; bottom24 | Flat native row without icon/pill/outline |
| Manuscript | padding36/48 regular;28/20 compact; hidden sidebar32; max760 left-aligned | Adaptive insets and anchored measure; heading26/30, leading1.4; distinct16/24 or20/28 gaps |
| Body paragraphs |17/30.6 compact,19/35.15 regular;24 paragraph gap | Blank-line separator typography no longer adds two paragraph gaps; source text untouched |
| Status | Fullwindow;36 compact/36.5 regular; Source11/13 | Fullwidth status host, local native save status retained |
| Library margins |20 compact/28 medium/32 regular; top24/28/32 | Responsive decisions now use full viewport, not content-pane width |
| Library heading/actions | heading41.5/47.5; action39.5; primary37.5; widths78.039/107.422 | Precise measured frames; medium controls stay inline |
| Library cards | square1px border; covers170/220; columns2/3; pitch246.5/301.5 | Plain editorial glyph covers replace fixture illustrations; no visible action ellipsis |
| Card typography | title15/22 or17/25,top13; metadata12/17.5 or12.5/18 | Editorial title and compact metadata frames matched |
| Creation | max880; padding24/20 compact,28 medium,32/40 wide; cards86/112 | Measured creation grid and native56 toolbar; six preset choices |
| Creation footer |61.5/73.5 high; Continue89.453x37.5 | Explicit native footer geometry; preserves actual title-entry continuation |
| Glass/appearance | Stable translucent chrome; no repeated flashes | Shared glass view retained; window appearance changed once, implicit layer actions disabled |

## Evidence and validation

- Latest same-content capture matrix: **25 route markers passed** across 390, 1024, 768, 507 and 335 widths. Five picker markers exposed an overly strict test of `UILabel.numberOfLines == 1`; the labels rendered on one line but allowed unlimited lines. The corrected regression checks actual rendered height, width fit and the effective attributed font. The bounded 335 picker and Settings rerun passed. An earlier 30-marker pass is historical, not the latest matrix result.
- The final 335 picker screenshot was visually inspected: Continue is on one line, Research paper and Blank document use the approved display labels, and the heading fits. Continue's effective attributed font is `SourceSans3-Roman_Regular` at 15pt; its text and label widths are both 57.5pt.
- Same-content screenshots: `/private/tmp/neon-approved-ios-viewports/approved-{390,1024,768,507,335}-{library,reopen,navigation,picker,history,settings}.png`, using the approved three-chapter manuscript and three Library titles. These are **simulated native viewport containers**, not real OS Split View. Native saved-status wording is retained.
- Native controls tests passed on actual iPhone and iPad simulator windows; the iPad adaptive orientation test passed. Explicit project context-menu interaction passes on both device families. The final corrected iPhone journey passed, including Settings return and manuscript preservation.
- The first final iPad journey timed out waiting for XCTest's app-animation-completion notification. Its overall result is failed even though the restarted runner printed an empty passing suite. Spindump samples showed the app main thread parked in the run loop and its animation manager idle, rather than a busy layout loop. The isolated retry completed the real recorded journey with one test, zero failures in 65.718 seconds; no timeout or assertion relaxation was used.
- Rapid appearance toggles preserve editor identity, text and selection; cancel prior snapshot overlays; and reuse the native glass view. Reduced motion removes the transition overlay. The bounded Settings regression also verifies that the layout-only blank-paragraph font cannot leak into caret typing attributes.
- Native UIGlassEffect and text rasterization remain platform rendering differences; no pixel-identical claim is made.

## Latest verification paths

- Build: `/private/tmp/neon-ios-exact-build.log` — passed.
- Same-content matrix: `/private/tmp/neon-approved-captures.log`; captures `/private/tmp/neon-approved-ios-viewports`.
- Bounded 335 picker and Settings: `/private/tmp/neon-picker-final-check.log` — both passed.
- Native controls, actual iPad adaptive rotation and explicit context-menu behavior: `/private/tmp/neon-ios-parity-verified-interaction/{iPhone,iPad}.log`. That run still had the superseded Settings-navigation-bar assertion, so its overall journey result is not a pass.
- Corrected iPhone journey: `/private/tmp/neon-ios-final-journeys/iPhone.log` — passed. Result bundle and video are in its family directory.
- First final iPad journey: `/private/tmp/neon-ios-final-journeys/iPad.log` — animation-quiescence timeout. Spindump: `/private/tmp/neon-ios-final-journeys/iPad/attachments/F387495D-48E9-450C-8775-567352DDD76D.txt`.
- Isolated iPad retry: `/private/tmp/neon-ios-final-ipad-retry/iPad.log` — passed (one test, zero failures, 65.718 seconds); orchestrator `/private/tmp/neon-final-ipad-retry.log`. The journey-only runner records prior controls results without claiming to rerun them.

The test-only viewport override is honored only with smoke/UI-test arguments. All capture libraries and preferences are isolated from production data.
