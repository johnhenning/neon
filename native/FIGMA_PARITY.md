# Native design-parity baseline

Reference: [Neon Figma](https://www.figma.com/design/DOW2IVUIDIt2Z4cM4XtM8I).
Reviewed S05 nodes include Mac light `34:72`, iPhone light `34:81`, and iPad
portrait light `144:16148`. Native Apple controls own window chrome, text input,
accessibility, menus and keyboard behavior. This baseline does not establish full
S05 or application-wide design parity.

## Implemented contract

- Native system UI fonts; Literata is the manuscript default and Source Sans is a
  separate manuscript choice. Default size is Mac 20 pt/mobile 18 pt, with a 640 pt
  writing measure. User preferences retain priority. Book headings are left aligned;
  other preset alignment semantics remain intact.
- Mobile project title lives in navigation, without a duplicate canvas title or
  decorative rule. Typography remains available from the action menu.
- History has a clock command and a separate return command. Search is independently
  accessible. An unchanged history round trip reuses the current section editor;
  restore invalidates its cache. Undo is local to an editor/section visit.
- Mac chapter rows expose a complete accessibility group with separate title and
  Actions controls. One sidebar toggle moves between expanded/collapsed positions;
  toolbar changes use identifiers. Geometry assertions compare the complete row.
- iPad starts with the sidebar hidden below 1000 pt. An explicit sidebar choice
  persists within that width class; changing layout class reapplies the width policy.

## Fixtures and reproducible captures

Use the XCTest driver to supply fixture JSON, a UUID preferences suite and a named
profile to the actual CMake-built app:

```sh
python3 native/scripts/ui_walkthrough.py macOS /absolute/path/Neon.app /absolute/path/evidence --fixture 3
python3 native/scripts/ui_walkthrough.py iPhone /absolute/path/Neon.app /absolute/path/evidence --device SIMULATOR_UDID --fixture 24chapters
```

Fixture variants are `0`, `1`, `3`, `many` (24 projects), `24chapters` and `longtext`.
Profiles default to `desktop` (20 pt) on Mac and `mobile` (18 pt) on iPhone/iPad;
`--profile desktop|mobile` overrides this. UI mode requires the driver's validated
profile/run environment. All `--smoke-*` modes also use fresh isolated preferences,
without requiring driver environment. UIKit smoke follows system appearance so
`ios_smoke.py` controls light/dark captures; Mac smoke switches appearance itself.
Production preferences and manuscripts are not reset for captures.

Fixtures preserve the prior prototype sample text/titles, not certified exact Figma
content or stable canonical document/section IDs. Approved `quiet-sea`, `stone-paths`,
`glass-field` and `coast` hires artwork exists in the review workspace under
`outputs/neon-deep-review/assets`; it is not bundled/rendered until the Library
artwork slice. Null fixture artwork explicitly records that gap.

Each XCTest capture attaches measured native window bounds (or null with a reason),
runtime OS, platform, preference profile, fixture, Figma node and checkout SHA/dirty
state. Unmapped captures have a null Figma node. Exported screenshot checksums and
capture metadata appear in `visual-manifest.json`; earlier direct simulator smoke
screenshots are outside that manifest. Checkout SHA is not independently verified
build provenance for an arbitrary supplied app path.

Recordings prefer XCTest's bounded real interaction video; mobile can fall back to
`simctl recordVideo` when XCTest footage is unavailable. Exported video is decoded
and checked for visual changes. `result.json` separates `ui_status` from
`recording_status`; usable footage does not establish a passing journey, and a
passing UI test does not establish valid footage. Overall success requires both.

## Verification and remaining acceptance

Apple builds, core/session tests and native smoke have run successfully during this
baseline iteration; local CLT checks also cover preference isolation (11 permanent
CTest cases), formatting/lint and portable boundaries. This supersedes the earlier
Linux-only compilation caveat. Recorded XCTest results remain candidate-specific.
Run `40236756993` at candidate `d1d69fb` passed the Mac recorded journey;
its 78.5-second XCTest video was decoded and visually inspected through typing,
navigation, History and Settings. Run `40240129933` at `24a8412` passed both iPhone
and iPad journeys after correcting the manuscript accessibility activation point.
The prior iPhone default tap hit the surrounding view at the rounded manuscript
boundary; the new interior point retains UIKit's normal touch/focus behavior and
the unchanged XCTest assertions. Bounded test-only window traces established the
cause without recording manuscript text.

Runs `40238182159` and `40240129933` selected only iOS for UIKit-only pushes;
Mac, core and the Mac report were skipped. Local pipeline coverage passes nine
Python tests plus the report-publisher checks. These results do not certify
untested UI variants.

Task 1 still requires exact canonical fixture text/titles/IDs/art, recorded variant
coverage, matching screenshot inspection and full cross-layout/theme acceptance.
Explicit caret/scroll preservation, restore-cache invalidation, and iPad sidebar
choice through Library/reopen/layout changes still need complete regression
coverage. Do not infer those guarantees from history text persistence alone.

Later staged work includes shared design controls, Library/creation, adaptive
heading/measure/status treatment, compact navigation and keyboard-safe layouts,
recovery, search, richer local editing and optional connected capabilities. Verify
line rhythm and light/dark captures at matching viewports while retaining preset
semantics and user typography. The baseline does not claim completion of those
stages or full design parity.

## CI selection

The native workflow classifies the latest validated PR push diff on synchronize
(and falls back to the whole PR diff when prior history is unavailable). Mac-only
and UIKit-only paths select their platform; shared adapters/resources/tests and
build changes select both. Markdown-only changes skip expensive native jobs.
Manual dispatch selects all targets. Concurrency is per platform/core job, so a new
Mac-only push does not cancel an independent UIKit validation. Classification tests
run before selecting jobs; skipped platform jobs are not fresh runtime evidence.

## Shared control contract (Task 2, 25 October 2026)

Design authority: component nodes `283:30668` (actions), `283:30694`
(selection), `283:30685` (fields), read with high-fidelity context and screenshots.
These nodes contain no static image assets. Native system typography is the
production interface contract. Source Sans 3 at 14/20 or 16/24 in Figma is a
preview fallback, not an instruction to replace native UI fonts. Literata remains
the manuscript/title font; Source Sans 3 remains a manuscript choice. Bundled font
registration and Georgia/system fallback remain in force; user font/size/spacing
preferences win. Native font metrics and OS-owned chrome are exact-match exceptions.

`DesignMetrics.h` names the 44 pt minimum target, 12 pt control radius, 8 pt image
radius, 8 pt breadcrumb gap and 32 pt scroll-bottom clearance. Fields deliberately
use radius 8, padding 12 and a 52 pt single-line minimum. Component widths 152/280
are examples, not fixed runtime widths. Multiline editors scroll real native text.
`Controls.h` provides native action/selection buttons, input wrappers and a numeric
stepper with visible value, accessible native stepper label, clamped bounds and a
callback. Read-only metadata should use paper/panel, ink text and a line border;
it must expose text rather than masquerade as a disabled editable field.

The PR integer RGB palette is preserved. `NeonDanger` maps live semantic danger
(.630,.200,.160)/(.950,.530,.460); `NeonActionText` maps light white and dark
(.120,.120,.110). Focus uses existing accent for fields, a 3 pt ink action outline
plus the native focus ring. This resolves the action sheet's ink stroke versus its
bronze-outline description explicitly. No dedicated focus or disabled Figma variable
exists. Disabled action opacity is .65 from the newer interaction sheet (older base
buttons use .50); fields use .50. Hover/pressed action opacity is .90/.75. Loading
suppresses activation and exposes a loading accessibility value; error uses visible
text as well as danger color. Selection uses selection fill, accent border and ink
text, never a solid primary-action fill. Menus keep native keyboard routing and now
use semantic danger and 44 pt rows. Numeric steppers retain native bounds/keyboard
semantics; input editors retain native delegates, selection, undo and IME APIs.

Launch the actual app with `--control-states` for a non-persistent catalog, action
counter, selection toggle, theme switch, fields and bounded numeric stepper.
`ControlStates.swift` is included in the generated XCTest driver alongside the
existing journey. `apple_controls_test` exercises native activation suppression,
selection accessibility, input state preservation, value bounds/callbacks and hit
bounds. Platform acceptance still requires XCTest on macOS and UIKit; these source
registrations alone are not evidence of an iOS run or VoiceOver/IME acceptance.

### Resolved handoff decisions

1. Compose S05 title/kicker hierarchy with the X19 destination inventory; preserve
   native window/navigation ownership. Later shell consumers implement that layout.
2. Add a versioned line-height multiple in the typography slice. Existing additive
   `manuscriptSpacing` values remain intact until explicit migration; this control
   foundation changes no saved preference or manuscript.
3. Default measure is 640 pt on Mac/wide iPad and 680 pt on portrait iPad when its
   adaptive layout ships; explicit user measure overrides take priority.
4. Production font intent and preview/native exceptions are stated above.
5. Add Article and Blank deliberately in the creation slice, preserving Meeting
   Notes and all existing preset IDs; no preset reinterpretation occurs here.
6. Remove design-only proposal/after-completion notes when those surfaces ship;
   rich-format descriptions must reflect supported content.
7. Counts, statuses, filenames, identities and revision destinations come from real
   state. Save-success Continue/Done require distinct behavior or a single action.
8. Optional sync/team/Git providers remain capability-gated later work. These shared
   controls do not imply provider availability or fabricate account state.
9. OS owns window buttons, keyboards, status bars and home indicators. Runtime focus,
   AX announcements, contrast, larger text, hardware keyboard and IME remain explicit
   cross-platform acceptance work, not guarantees inferred from Figma examples.
