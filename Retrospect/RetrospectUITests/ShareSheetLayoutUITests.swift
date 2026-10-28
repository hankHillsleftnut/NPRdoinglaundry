//
//  ShareSheetLayoutUITests.swift
//  #220 QA batch 9: the share sheet (EX-1) with the keyboard up and at AX3. Nothing overlaps, the header
//  never goes under the status bar, "save" sits above the keyboard and never covers the "why" field, and
//  the mic stays tappable. Runs in the launcher (`-Screen EX-1 -State ready -Data sample`). The UI target
//  is deliberately NOT in Platform.xctestplan (hosted CI runs unit tests only); a QA build adds it for its
//  own run. Stills go to the test result, and to `SHARE_LAYOUT_SHOTS_DIR` when that is set.
//
import XCTest

final class ShareSheetLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-Screen", "EX-1", "-State", "ready", "-Data", "sample", "-Appearance", "light"]
        if let contentSize {
            app.launchArguments += ["-ContentSize", contentSize]
        }
        app.launch()
        XCTAssertTrue(app.buttons["share.save"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func whyField(_ app: XCUIApplication) -> XCUIElement {
        let view = app.textViews["share.why"]
        return view.exists ? view : app.textFields["share.why"]
    }

    /// The top of the screen the status bar owns (Dynamic Island phones ~62, SE 20): the header starts below it.
    @MainActor
    private func statusBarBottom(_ app: XCUIApplication) -> CGFloat {
        app.windows.firstMatch.frame.height > 700 ? 54 : 20
    }

    @MainActor
    func testKeyboardUpKeepsHeaderAndFieldClear() {
        let app = launch()
        let field = whyField(app)
        field.tap()
        field.typeText("because it explains the monday standup, and the bit after it")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let save = app.buttons["share.save"]
        let cancel = app.buttons["share.cancel"]
        // the header stays pinned below the status bar
        XCTAssertTrue(cancel.isHittable)
        XCTAssertGreaterThanOrEqual(cancel.frame.minY, statusBarBottom(app))
        // save sits above the keyboard and never covers the field (give the reveal scroll a moment to land)
        XCTAssertLessThanOrEqual(save.frame.maxY, keyboard.frame.minY + 1)
        let deadline = Date().addingTimeInterval(3)
        while save.frame.intersects(field.frame), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertFalse(save.frame.intersects(field.frame), "save \(save.frame) covers the field \(field.frame)")
        keep(app, "keyboard-up")
    }

    /// Saves a still for a QA bundle when `SHARE_LAYOUT_SHOTS_DIR` names a folder (pass it to xcodebuild as
    /// `TEST_RUNNER_SHARE_LAYOUT_SHOTS_DIR`); otherwise it only attaches the still to the test result.
    @MainActor
    private func keep(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "EX-1-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["SHARE_LAYOUT_SHOTS_DIR"], !dir.isEmpty else { return }
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("EX-1-\(name).png"))
    }

    @MainActor
    func testAX3NothingOverlaps() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let save = app.buttons["share.save"]
        let cancel = app.buttons["share.cancel"]
        let title = app.staticTexts["share.title"]
        XCTAssertFalse(cancel.frame.intersects(title.frame), "cancel \(cancel.frame) touches the title \(title.frame)")
        // scroll the field into view; it and the mic are never under save
        let field = whyField(app)
        var tries = 0
        while !field.isHittable, tries < 4 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(field.isHittable)
        XCTAssertFalse(save.frame.intersects(field.frame), "save \(save.frame) covers the field \(field.frame)")
        let mic = app.buttons["share.why"]
        XCTAssertTrue(mic.isHittable)
        XCTAssertFalse(save.frame.intersects(mic.frame), "save \(save.frame) covers the mic \(mic.frame)")
        keep(app, "ax3-field")
        mic.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the mic didn't raise the keyboard")
    }
}
