import XCTest
#if !os(macOS)
import UIKit
#endif

/// Operates the shipping CMake-built app through accessibility, never smoke selectors.
final class Walkthrough: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if os(macOS)
        app = XCUIApplication(bundleIdentifier: "com.johnhenning.neon.nativeprototype")
        #else
        app = XCUIApplication(bundleIdentifier: "com.johnhenning.neon.applepreview")
        #endif
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment = ProcessInfo.processInfo.environment.filter { $0.key.hasPrefix("NEON_UI_") }
        app.launch()
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func activate(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 15), "Missing control: \(target)")
        XCTAssertTrue(target.isHittable, "Control is not hittable: \(target)")
        #if os(macOS)
        target.click()
        #else
        target.tap()
        #endif
        // Deliberate viewing pause, not a substitute for the assertions below.
        Thread.sleep(forTimeInterval: 0.7)
    }

    func capture(_ name: String, wholeScreen: Bool = false) {
        let screenshot = wholeScreen ? XCUIScreen.main.screenshot() : app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        var metadata = (try? JSONSerialization.jsonObject(with:
            Data((ProcessInfo.processInfo.environment["NEON_UI_CAPTURE_CONTEXT"] ?? "{}").utf8))) as? [String: Any] ?? [:]
        // The root Application frame can be infinite on macOS. Capture native
        // window bounds and reject unavailable geometry before JSON encoding.
        let window = app.windows.firstMatch
        let frame = window.frame
        metadata["capture"] = name
        if name == "01-library" {
            #if os(macOS)
            metadata["figma_node"] = "34:8"
            #else
            metadata["figma_node"] = NSNull()
            #endif
        } else if !name.hasPrefix("02-") {
            metadata["figma_node"] = NSNull()
        }
        if window.exists && [frame.minX, frame.minY, frame.width, frame.height].allSatisfy({ $0.isFinite })
            && frame.width > 0 && frame.height > 0 {
            metadata["viewport"] = ["x": frame.minX, "y": frame.minY,
                                    "width": frame.width, "height": frame.height, "unit": "points"]
        } else {
            metadata["viewport"] = NSNull()
            metadata["viewport_unavailable_reason"] = "Native window bounds unavailable or nonfinite"
        }
        metadata["runtime_os"] = ProcessInfo.processInfo.operatingSystemVersionString
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]) {
            let details = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            details.name = name + "-metadata"
            details.lifetime = .keepAlways
            add(details)
        }
    }

    func chapters() {
        #if !os(macOS)
        if !element("section-1").isHittable {
            activate(app.buttons["navigation-toggle"])
        }
        #endif
    }

    func assertUniqueChapterRows() {
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "section-0").count, 1)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "section-1").count, 1)
    }

    func testIPadAdaptiveEditorOrientation() throws {
        #if os(macOS)
        throw XCTSkip("UIKit orientation coverage")
        #else
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Requires an iPad")
        }
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
        app.launch()
        let window = app.windows.firstMatch
        let project = app.buttons["The Quiet Sea"]
        activate(project)
        let manuscript = element("manuscript")
        XCTAssertTrue(manuscript.waitForExistence(timeout: 15))
        guard window.frame.width >= 1000 && window.frame.height > window.frame.width else {
            throw XCTSkip("Requires the 13-inch portrait regression viewport")
        }
        let draft = manuscript.value as? String
        func waitForOrientation(_ landscape: Bool) {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                landscape ? window.frame.width > window.frame.height
                          : window.frame.height > window.frame.width
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 15), .completed)
        }
        func assertSidebar(_ visible: Bool) {
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let row = self.element("section-0")
                let sidebarVisible = row.exists && row.isHittable
                let leading = manuscript.frame.minX - window.frame.minX
                return visible ? sidebarVisible && leading > 200
                               : !sidebarVisible && leading < 100
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
            if visible {
                assertUniqueChapterRows()
                XCTAssertTrue(window.frame.contains(element("section-0").frame))
            }
            XCTAssertEqual(manuscript.value as? String, draft)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "manuscript").count, 1)
        }
        func selectChapter(_ index: Int, expectedText: String?) {
            let row = element("section-\(index)")
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            // XCTest can report a visible iPad row as non-hittable after rotation.
            // Exercise a real touch at its current frame and verify the document
            // changes; no app-side selector or synthetic session switch is used.
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)).tap()
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                manuscript.value as? String == expectedText
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed)
        }
        assertSidebar(true)
        capture("adaptive-13-portrait-default", wholeScreen: true)
        XCUIDevice.shared.orientation = .landscapeRight
        waitForOrientation(true)
        assertSidebar(true)
        selectChapter(1, expectedText: "By noon the water had drawn back from the old stone steps.")
        selectChapter(0, expectedText: draft)
        capture("adaptive-13-landscape-default", wholeScreen: true)
        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(false)
        assertSidebar(true)
        activate(element("navigation-toggle"))
        assertSidebar(false)
        XCUIDevice.shared.orientation = .landscapeRight
        waitForOrientation(true)
        assertSidebar(false)
        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(false)
        assertSidebar(false) // Explicit writer choice survives later rotations.
        capture("adaptive-13-portrait-manual-hidden", wholeScreen: true)
        activate(element("navigation-toggle"))
        assertSidebar(true)
        #endif
    }

    func testRecordedEditorJourney() {
        let variant = ProcessInfo.processInfo.environment["NEON_UI_FIXTURE"] ?? "3"
        if variant == "0" {
            XCTAssertTrue(element("library-project-count-0").waitForExistence(timeout: 15),
                          "Library must finish loading the empty fixture")
            XCTAssertTrue(app.staticTexts["Library"].exists || app.navigationBars["Library"].exists)
            XCTAssertFalse(app.staticTexts["The Quiet Sea"].exists)
            XCTAssertFalse(app.buttons["The Quiet Sea"].exists)
            capture("00-empty-library")
            return
        }
        let projectTitle = variant == "longtext"
            ? "The Quiet Sea — a long project title for narrow window and accessibility coverage"
            : "The Quiet Sea"
        // Both native Library title controls retain button activation semantics;
        // the separate cover button has the distinct label "Open …".
        let project = app.buttons[projectTitle]
        XCTAssertTrue(project.waitForExistence(timeout: 15))
        capture("01-library")
        #if !os(macOS)
        project.press(forDuration: 0.7)
        XCTAssertTrue(app.buttons["Rename"].waitForExistence(timeout: 5), "Project actions remain available by long press")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        #endif
        activate(project)
        #if !os(macOS)
        XCTAssertFalse(app.buttons["Move to Trash…"].exists, "A normal tap must open the project, not its context menu")
        #endif
        #if os(macOS)
        activate(element("section-0"))
        #else
        if !element("manuscript").isHittable {
            activate(element("section-0"))
        }
        #endif
        let editor = element("manuscript")
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        #if os(macOS)
        func assertSidebarTogglePlacement() {
            let toggle = app.buttons["Toggle sidebar"]
            let history = app.buttons["Version history"]
            let chapterRow = element("section-row-0")
            XCTAssertTrue(chapterRow.waitForExistence(timeout: 5))
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "section-row-0").count, 1)
            let title = chapterRow.descendants(matching: .any).matching(identifier: "section-0").firstMatch
            let actions = chapterRow.buttons["section-actions-0"]
            XCTAssertTrue(title.exists, "Chapter title must remain independently accessible in its row")
            XCTAssertTrue(actions.exists, "Chapter Actions must remain independently accessible in its row")
            XCTAssertTrue(chapterRow.frame.contains(title.frame), "Chapter row must contain its title bounds")
            XCTAssertTrue(chapterRow.frame.contains(actions.frame), "Chapter row must contain its Actions bounds")
            XCTAssertEqual(app.buttons.matching(identifier: "Toggle sidebar").count, 1)
            XCTAssertEqual(toggle.frame.midY, history.frame.midY, accuracy: 8)
            XCTAssertGreaterThan(toggle.frame.midX, chapterRow.frame.midX)
            XCTAssertLessThanOrEqual(toggle.frame.maxX, chapterRow.frame.maxX + 24)
        }
        assertSidebarTogglePlacement()
        #endif
        #if !os(macOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertEqual(app.buttons.matching(identifier: "navigation-toggle").allElementsBoundByIndex.filter { $0.isHittable }.count, 1)
            if !element("section-0").isHittable {
                capture("02-ipad-portrait-writing")
                activate(app.buttons["navigation-toggle"])
            }
            XCTAssertTrue(element("section-0").isHittable)
            let expandedWidth = editor.frame.width
            activate(app.buttons["navigation-toggle"])
            XCTAssertFalse(element("section-0").isHittable)
            XCTAssertGreaterThan(editor.frame.width, expandedWidth)
            capture("02-ipad-focus")
            activate(app.buttons["navigation-toggle"])
            XCTAssertTrue(element("section-0").isHittable)
            XCTAssertLessThanOrEqual(element("section-0").frame.maxX, editor.frame.minX)
            assertUniqueChapterRows()
        } else {
            activate(app.buttons["navigation-toggle"])
            XCTAssertTrue(element("section-0").isHittable)
            XCTAssertFalse(editor.isHittable)
            assertUniqueChapterRows()
            activate(element("section-0"))
        }
        #endif
        #if os(macOS)
        assertUniqueChapterRows()
        XCTAssertTrue(app.buttons["section-actions-0"].exists)
        for _ in 0..<3 {
            activate(app.buttons["Toggle sidebar"])
            XCTAssertFalse(element("section-1").isHittable)
            activate(app.buttons["Toggle sidebar"])
            XCTAssertTrue(element("section-1").isHittable)
            assertSidebarTogglePlacement()
        }
        #endif
        capture("02-editor")
        activate(editor)
        capture("02-editor-after-focus")
        editor.typeText("\nNeon recorded UI persistence check.")
        chapters()
        activate(element("section-1"))
        XCTAssertFalse((element("manuscript").value as? String ?? "")
            .contains("Neon recorded UI persistence check."))
        if variant == "24chapters" {
            activate(element("manuscript"))
            element("manuscript").typeText("\nIndependent second chapter marker.")
        }
        capture("03-next-chapter")
        chapters()
        activate(element("section-0"))
        XCTAssertTrue((element("manuscript").value as? String ?? "")
            .contains("Neon recorded UI persistence check."))
        XCTAssertFalse((element("manuscript").value as? String ?? "")
            .contains("Independent second chapter marker."), "Equal source text must not share an editor")
        capture("04-saved-edit")
        #if os(macOS)
        activate(app.buttons["Toggle sidebar"])
        XCTAssertFalse(element("section-1").isHittable)
        XCTAssertTrue(app.buttons["Version history"].isHittable)
        capture("05-focus")
        activate(app.buttons["Toggle sidebar"])
        XCTAssertTrue(element("section-1").isHittable)
        assertSidebarTogglePlacement()
        XCTAssertTrue(app.buttons["Version history"].isHittable)
        // Create an undo operation in this editor instance, after section changes.
        // Section navigation intentionally gives each section its own undo scope.
        activate(element("manuscript"))
        // Clicking the resized viewport can land inside the earlier persistence
        // marker. Append at the native document end so this edit cannot bisect it.
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: .command)
        element("manuscript").typeText("\nHistory undo scope marker.")
        XCTAssertTrue((element("manuscript").value as? String ?? "").contains("History undo scope marker."))
        #endif
        // History belongs to the editor toolbar. On compact UIKit layouts,
        // navigating back to chapters removes that toolbar from the screen.
        activate(app.buttons["Version history"].firstMatch)
        XCTAssertTrue(app.buttons["Back to editor"].waitForExistence(timeout: 10))
        XCTAssertFalse(element("manuscript").exists)
        XCTAssertFalse(app.searchFields.firstMatch.isHittable)
        capture("06-history")
        activate(app.buttons["Search History"])
        let historySearch = app.searchFields.firstMatch
        XCTAssertTrue(historySearch.waitForExistence(timeout: 5))
        activate(historySearch)
        historySearch.typeText("NoSuchRevisionForWalkthrough")
        let revisionPreview = element("Read-only revision preview")
        #if os(macOS)
        let noMatchesMessage = "No versions match this filter."
        #else
        let noMatchesMessage = "No matching revisions."
        #endif
        XCTAssertTrue((revisionPreview.value as? String ?? "").contains(noMatchesMessage))
        activate(app.buttons["Search History"])
        XCTAssertFalse(historySearch.isHittable)
        XCTAssertFalse((revisionPreview.value as? String ?? "").contains(noMatchesMessage))
        activate(app.buttons["Back to editor"])
        XCTAssertTrue(element("manuscript").waitForExistence(timeout: 10))
        XCTAssertTrue((element("manuscript").value as? String ?? "").contains("Neon recorded UI persistence check."))
        #if os(macOS)
        XCTAssertTrue((element("manuscript").value as? String ?? "").contains("History undo scope marker."))
        activate(element("manuscript"))
        app.typeKey("z", modifierFlags: .command)
        XCTAssertFalse((element("manuscript").value as? String ?? "")
            .contains("History undo scope marker."), "History return must preserve current editor undo")
        XCTAssertTrue((element("manuscript").value as? String ?? "")
            .contains("Neon recorded UI persistence check."), "Undo must retain edits from the prior section visit")
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertTrue((element("manuscript").value as? String ?? "")
            .contains("History undo scope marker."), "History return must preserve current editor redo")
        app.typeKey(",", modifierFlags: .command)
        let settings = element("settings-page")
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        XCTAssertTrue(app.searchFields["Search settings"].exists)
        capture("07-settings")
        activate(element("settings-back"))
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: settings)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertTrue(element("manuscript").isHittable)
        XCTAssertTrue((element("manuscript").value as? String ?? "")
            .contains("History undo scope marker."), "Settings return must preserve the editor draft")
        #else
        chapters()
        activate(element("Settings"))
        XCTAssertTrue(app.buttons["settings-back"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Settings"].exists)
        capture("07-settings")
        activate(app.buttons["settings-back"])
        XCTAssertTrue(element("manuscript").waitForExistence(timeout: 10))
        XCTAssertTrue((element("manuscript").value as? String ?? "").contains("Neon recorded UI persistence check."))
        #endif
    }
}
