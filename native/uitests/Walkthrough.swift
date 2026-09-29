import XCTest

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

    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func chapters() {
        #if !os(macOS)
        if !element("section-1").isHittable {
            activate(app.buttons["Show or hide Chapters"])
        }
        #endif
    }

    func testRecordedEditorJourney() {
        #if os(macOS)
        let project = app.buttons["The Quiet Sea"]
        #else
        let project = app.staticTexts["The Quiet Sea"]
        #endif
        XCTAssertTrue(project.waitForExistence(timeout: 15))
        capture("01-library")
        activate(project)
        #if os(macOS)
        activate(element("section-0"))
        #else
        if !element("manuscript").isHittable {
            activate(element("section-0"))
        }
        #endif
        let editor = element("manuscript")
        XCTAssertTrue(editor.waitForExistence(timeout: 15))
        capture("02-editor")
        activate(editor)
        editor.typeText("\nNeon recorded UI persistence check.")
        chapters()
        activate(element("section-1"))
        XCTAssertFalse((element("manuscript").value as? String ?? "")
            .contains("Neon recorded UI persistence check."))
        capture("03-next-chapter")
        chapters()
        activate(element("section-0"))
        XCTAssertTrue((element("manuscript").value as? String ?? "")
            .contains("Neon recorded UI persistence check."))
        capture("04-saved-edit")
        #if os(macOS)
        activate(app.buttons["Toggle sidebar"])
        XCTAssertFalse(element("section-1").isHittable)
        capture("05-focus")
        activate(app.buttons["Toggle sidebar"])
        XCTAssertTrue(element("section-1").isHittable)
        #else
        chapters()
        #endif
        activate(app.buttons["History"])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10))
        capture("06-history")
        activate(app.buttons["Done"])
        #if os(macOS)
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.windows["Settings"].waitForExistence(timeout: 10))
        capture("07-settings")
        activate(app.windows["Settings"].buttons[XCUIIdentifierCloseWindow])
        #else
        activate(app.buttons["Settings"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        capture("07-settings")
        activate(app.buttons["Done"])
        #endif
    }
}
