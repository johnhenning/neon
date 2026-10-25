# Task 2: Shared native controls

Implemented reusable AppKit/UIKit `NeonButton`, `NeonField`, and
`NeonNumericStepper` adapters, named design metrics, danger/on-accent semantics,
neutral shared selectors, and 44 pt context menu commands. Editors remain real
native NSTextField/NSTextView and UITextField/UITextView, with public native APIs
for consumers. Native keyboard, text selection and undo paths are retained.
History's existing scope action now updates shared selection state instead of
reapplying the old bronze pill style. No core, manuscript or saved preference
schema changed. The catalog's theme action touches only its window appearance;
it does not write defaults or initialize a library/coordinator.

Read high-fidelity live Figma context and screenshots for component families
`283:30668`, `283:30694`, `283:30685` in session
`af478bf8-fdeb-4f01-b015-eeee53e47072`. No static assets occur in those controls.
`FIGMA_PARITY.md` records all nine handoff decisions, production/fallback font
intent, semantic variable mapping, focus/disabled differences in the design,
and deferred shell/line-height/preset/provider work.

## Reachable fixture and tests

Launch `/private/tmp/neon-visual-controls/Neon.app --control-states` (or execute
its Contents/MacOS/Neon with that argument). The UIKit app supports the same flag.
The isolated catalog provides activation counter, primary/secondary buttons,
neutral selection, loading, disabled, error action, theme toggle, single/multiline
native fields, cycling default/error/disabled field states, and native bounded
stepper. Actual pointer press/hover and keyboard focus use native controls.

`ControlStates.swift` is copied and compiled into the XCTest driver, run separately
into `controls.xcresult`, and exports `controls-attachments`. The normal editor
journey is explicitly selected into `walkthrough.xcresult`; only that bundle feeds
the validated walkthrough video. The orchestration regression includes a separate
control MP4 and proves it does not pollute the designated editor preview. Control
test failure also fails overall UI status while preserving journey diagnostics.

`apple_controls_test` permanently registers in CTest. It asserts enabled/disabled/
loading activation, selection AX values, numeric clamping and enabled callbacks,
native undo configuration and input text/selection preservation through state
changes, and minimum button layout bounds in both appearances.

## Validation

- Fresh local CLT CMake build in `/private/tmp/neon-visual-controls`: PASS. Used
  deployment target 14.0 and explicit installed SDK libc++ include path for C++
  and Objective-C++ flags, matching the documented local toolchain workaround.
- CTest excluding native_ui: 15/15 PASS, including controls, core, persistence,
  preference isolation and compatibility cases.
- native_ui initially aborted in sandbox LaunchServices `_RegisterApplication`
  before app code. Re-run outside sandbox with disposable fixture: PASS, 14.21 s.
- Controls executable native fixture assertions and light/dark capture: PASS.
- Python script suite: 9/9 PASS, including isolated control/journey recordings.
- Required `PATH=/private/tmp/neon-quality-env/bin:$PATH
  /private/tmp/neon-quality-env/bin/python native/scripts/quality.py`: PASS before
  follow-up commit (formatting, lint, portable dependency boundary, whitespace).
  The first implementation commit was made after a failed lint invocation because
  the shell continued; follow-up adds the required string include and records
  the verified passing quality run.

Inspected light/dark fixture PNGs at
`/private/tmp/neon-visual-controls/control-light.png` and `control-dark.png`.
The corrected captures have matching field geometry and neutral selection,
semantic paper/panel/ink/action/error treatments. Native interface font and
platform-native stepper appearance are documented design exceptions. These
short-lived capture processes exit; no persistent catalog is left running.

## Remaining acceptance limits

Full Xcode is absent locally. UIKit compilation/runtime, the newly registered
XCTest controls test on both platforms, live hardware-keyboard focus/hover/press,
IME composition, VoiceOver, larger text and all state/theme screenshot acceptance
still require CI and native review. Existing manual controls preserve native input
mechanisms; the tests do not prove all input-method behaviors. These gaps are not
reported as passing tests or full design parity. Provider/session functionality,
new presets, line-height migration and adaptive shell geometry remain later tasks.
