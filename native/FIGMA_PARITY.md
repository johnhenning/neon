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
