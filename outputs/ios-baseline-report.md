# iOS baseline investigation

Base: 4162cb4. Scope: native/ios/NativeApp.mm.

## Changes

- Retain explicit iPad sidebar visibility across project/library navigation and size changes within the existing narrow/wide breakpoint (<1000pt). Reset to the layout default only when crossing that breakpoint. Library presentation still shows its primary column without modifying the writer's saved choice.
- Book headings remain left aligned; other presets honor centeredHeading.
- Use the shared UITestFixtures.h NeonPreferences() and NeonSeedUITestLibrary() interfaces, supplied by the fixtures worker. Smoke seeding remains unchanged.
- Add a UITextView subclass which returns the original hitTest result unchanged and logs at most eight hit tests per editor in --ui-testing mode. Logs include bounds point, frame, editable/selectable/first-responder/window state, and hit ancestry. Editing-began logs identify successful focus. No forced focus, extra gesture recognizer or assertion removal.

## Focus evidence and limit

Reviewed GitHub Actions job 110686213844 for johnhenning/neon. The iPhone journey opens chapter zero, returns to chapters, reopens chapter zero, then taps manuscript at t35.25s. typeText at t36.75s fails with neither element nor descendant having keyboard focus. The text view remains {{0,233},{402,573.3}}, contains preview text, and has no keyboard-visible geometry change. The same job's iPad journey passes.

Source tracing found no custom ancestor tap recognizer; the transition snapshot is noninteractive and its 0.18s animation has completed well before the tap. editable is set from selectedSectionID. That evidence narrows the failure to hit delivery/responder acquisition but does not prove a cause. The focus failure is unresolved pending fresh CI diagnostics; changing UIKit focus semantics speculatively would conceal this uncertainty.

## Validation

PASS: PATH=/private/tmp/neon-quality-env/bin:$PATH /private/tmp/neon-quality-env/bin/python native/scripts/quality.py (formatting, lint, dependency checks). cpplint emitted Python codecs.open deprecation warnings.

Unavailable: xcodebuild -version fails because active developer directory is CommandLineTools, not full Xcode. No iOS compile, simulator, XCTest, screenshots, red/green runtime verification, or working iOS build claim is made. Shared fixture header must be integrated before compiling this commit.

## Proposed runtime regression coverage (sent to root)

- Explicit iPad sidebar choice survives returning through Library and reopening another project.
- Same breakpoint resizing preserves the choice; crossing breakpoint uses new layout default.
- Non-Book centeredHeading presets retain their heading semantics.
- Keep manuscript tap/type persistence test and capture focus diagnostics before typing; assert keyboard presence to localize failure.
- Launch under isolated preferences as well as isolated fixture library; previous startup cleared only SmokeLibrary and leaked standard-user preferences.

## Run 55: event-delivery cause identified

Run 40238182159 / commit ff48235 exported `iPhone/focus-window-diagnostics.log` in artifact 12617050615. The fifth touch, corresponding to the unchanged `activate(editor)` call before the first typeText, was delivered at `{5,233}` to the editor's root `UIView`, not `NeonManuscriptView`. Its after-dispatch responder is empty. The AX manuscript frame is `{{0,233},{402,573.3}}`. The target lies at its top/leading edge; fractional layout and point rounding can place that edge point outside the actual text-view hit bounds. This is an event-delivery failure, not a request to make an already-hit editor become first responder.

The UIKit repair overrides the manuscript's accessibilityActivationPoint to the center of its screen-converted bounds. `UIAccessibilityConvertFrameToScreenCoordinates` supplies the scene/rotation-aware conversion and derives the point from current bounds, including the scroll view's bounds origin. The manuscript is constrained inside its visible safe content region; its center is an interior point rather than an inset/edge point. No focus call, recognizer, XCTest coordinate, or assertion is changed. The existing tap/type test is the regression test and previously failed in runs 53–55. Fresh CI must confirm the touch now reaches NeonManuscriptView and typing succeeds.

Validation for this repair: native/scripts/quality.py passes with pinned tools; git diff --check passes. Simulator runtime verification remains unavailable locally; do not claim the focus issue resolved until the unchanged journey passes in CI.
