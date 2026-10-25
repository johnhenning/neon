import XCTest

/// Runs the isolated native catalog through the same CMake app used by Walkthrough.
final class ControlStates: XCTestCase {
    func testControlsAndThemes() {
        #if os(macOS)
        let app = XCUIApplication(bundleIdentifier: "com.johnhenning.neon.nativeprototype")
        #else
        let app = XCUIApplication(bundleIdentifier: "com.johnhenning.neon.applepreview")
        #endif
        app.launchArguments = ["--control-states"]
        app.launch()
        defer { app.terminate() }
        let primary = app.buttons["Activations: 0"]
        XCTAssertTrue(primary.waitForExistence(timeout: 10))
        for name in ["Activations: 0", "Secondary", "Selected", "Loading", "Disabled"] {
            let control = app.buttons[name]
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
        }
        XCTAssertFalse(app.buttons["Disabled"].isEnabled)
        let selection = app.buttons["Selected"]
        XCTAssertEqual(selection.value as? String, "Selected")
        #if os(macOS)
        selection.click()
        primary.click()
        #else
        selection.tap()
        primary.tap()
        #endif
        XCTAssertEqual(selection.value as? String, "Not selected")
        XCTAssertEqual(primary.label, "Activations: 1")
        for theme in ["light", "dark"] {
            for state in ["default", "error", "disabled"] {
                let fields = XCTAttachment(screenshot: app.screenshot())
                fields.name = "controls-\(theme)-fields-\(state)"
                fields.lifetime = .keepAlways
                add(fields)
                #if os(macOS)
                app.buttons["Field states"].click()
                #else
                app.buttons["Field states"].tap()
                #endif
            }
            let capture = XCTAttachment(screenshot: app.screenshot())
            capture.name = "controls-\(theme)"
            capture.lifetime = .keepAlways
            add(capture)
            #if os(macOS)
            app.buttons["Change theme"].click()
            #else
            app.buttons["Change theme"].tap()
            #endif
        }
    }
}
