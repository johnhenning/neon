# Mac baseline changes

NativeApp.mm now keeps sidebar/title toolbar items in the declared order (no navigation-item reordering), mutates the tracking divider and preceding spacer by identifier, exposes each chapter title independently, restores an Actions button per chapter, preserves current-chapter AX value on the title, limits the Book left-heading override to Book, and stages a newly opened session before replacing the previous session. Existing openProject already stages open safely and remains intact.

Fixture integration imports Preferences.h / UITestFixtures.h, uses isolated NeonPreferences(), and selects fixture seeding only for --ui-testing; legacy --smoke-test retains seedPreview. These headers are provided by the fixture worker and intentionally excluded from this commit.

## Investigation evidence

CI-reported failing assertion remains unchanged: toggle midpoint140 was left of section midpoint167.5. AppKit SDK NSToolbarItem.h explicitly documents that navigational items may be specially positioned outside toolbarDefaultItemIdentifiers order. Both toggle and title had navigational=YES while the layout depended on flexible space preceding the toggle and a tracking separator following it. Removing those flags addresses that ordering conflict. This remains a source-supported hypothesis until the strict XCUI placement assertion passes in CI or the parent completes its live geometry check.

Chapter container had an AX label/value but no independent Actions control. Removed the aggregate container label, explicitly ignored its AX element, exposed the inline title, and restored section-actions-N controls.

The new-project path assigned openURL directly to self.session after successful creation, losing an existing session if open failed. It now uses the same temporary-session pattern as openProject.

## Validation

- Full native CLT CMake build passes using CXX and OBJCXX flags `-isystem /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1`.
- `native/scripts/quality.py` passes with pinned quality environment. Only cpplint Python deprecation warnings.
- Sandboxed CTest: native_ui aborts before output; apple_document_session, workspace, document pass.
- Outside sandbox CTest: all 4 pass in13.63s, including native_ui. Existing unrelated EditorialTheme.mm signedness warnings and duplicate-library linker warning remain.
- Inspected smoke native-editor.png and discovered existing screencapture captures the foreground ChatGPT desktop rather than Neon. Changed capture to target self.window.windowNumber explicitly. This last capture argument change compiles but GUI rerun is deferred while parent owns the interactive app.
- Full Xcode / XCTest unavailable locally (xcode-select points at CommandLineTools). No claim of recorded journey, AX geometry, or screenshot parity completion.

Parent owns Walkthrough regression extensions and integration. No pushes.

## Follow-up: full chapter-row geometry

CI49 proved the midpoint ordering is fixed, then failed the unchanged trailing-edge limit: toggle.maxX284 exceeded title.maxX250+24. Restoring the Actions control legitimately narrows the title text field; its bounds no longer represent the entire sidebar row. Expose the existing full-width NeonChapterRow as AXGroup `section-row-N` with explicit title/Actions children, while retaining `section-N` on the editable title. The XCTest owner compares the same placement thresholds to this semantic row and requires its title and Actions child bounds to be contained.

Parent live CUA inspection confirms `section-row-0/1` groups contain `section-0/1` title children and Actions buttons. Visual geometry remains unchanged. CUA also exposes an Actions wrapper with the same identifier, but XCTest `.buttons` targets its actual button descendant.

Fresh implementation-source CLT build at `/private/tmp/neon-mac-row` passes. Quality passes. All14 non-GUI CTest cases pass (session, preferences cases, portable document/workspace); GUI was deliberately not rerun while parent owned desktop inspection. This follow-up makes the row geometry observable without removing independent chapter/control access or increasing placement tolerances.
