# Editor shell: first implementation slice

Reference file: https://www.figma.com/design/DOW2IVUIDIt2Z4cM4XtM8I

High-fidelity context reviewed for S05 Mac light (`34:72`), iPhone light
(`34:81`), and iPad portrait light (`144:16148`). The native Apple controls remain
responsible for window chrome, input, accessibility, menus, and keyboard behavior.

Implemented in this slice:

- Native system UI fonts; Source Sans remains a distinct manuscript font choice.
- Left-aligned chapter kicker/title and a shared maximum writing measure of 640 pt.
  Default manuscript size is 20 pt on Mac and 18 pt on mobile; saved preferences
  continue to override defaults. Settings show the matching defaults.
- Mobile project title moves into navigation; the duplicate canvas title and
  decorative rule are removed. Typography remains available in the action menu.
- Version history is a clock command, with a separate return-to-editor command.
  History search remains independently accessible, including on narrow screens.
- Returning from history reuses the editor when session, section and text still
  match. Restore invalidates this cache. Mac also restores the scroll position.
- iPad starts with the primary pane hidden below 1000 pt. Rotation reapplies the
  width policy; the navigation control can explicitly show or hide the pane.
- Mac chapter navigation precedes Library/Trash; chapter rows use smaller native
  labels and retain inline rename and action menus.

Verification:

- Portable core tests pass (2/2) on Linux.
- `native/scripts/quality.py` passes with clang-format 19.1.7 and cpplint 2.0.2.
- Updated XCTest walkthrough covers the history command/return, navigation,
  history search, edits and save/reopen. Native smoke includes editor identity and
  selection checks across the history round trip.
- Apple compilation, smoke, XCTest and screenshot review are pending the branch
  push and GitHub Actions. Linux checks do not establish native runtime success.

Still required before claiming S05 parity:

- Inspect light/dark Apple captures at matching viewport sizes; refine native
  toolbar title placement, sidebar dimensions and pinned bottom actions.
- Match manuscript paragraph/line rhythm without overriding preset semantics or
  existing user preferences. Let the heading scroll naturally with the manuscript.
- Finish status bar treatment and adaptive wide-iPad typography.
- Complete separate full-screen compact navigation and keyboard-visible layouts.
- Implement the broader project search from NEON-073; this slice adds no placeholder
  search button. Library/chooser, other screen families and deferred rich content
  remain separate implementation slices in the October 1 Notion plan.
