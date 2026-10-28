//
//  ShareSheetLayoutUITests.swift
//  #220 QA batch 9: the share sheet (EX-1) with the keyboard up and at AX3. Nothing overlaps, the header
//  never goes under the status bar, "save" sits above the keyboard and never covers the "why" field, and
//  the mic stays tappable. Runs in the launcher (`-Screen EX-1 -State ready -Data sample`). The UI target
//  isn't in Platform.xctestplan (hosted CI runs unit tests only), so this runs in the local QA build.
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
        // save sits above the keyboard and never covers the field
        XCTAssertLessThanOrEqual(save.frame.maxY, keyboard.frame.minY + 1)
        XCTAssertFalse(save.frame.intersects(field.frame), "save \(save.frame) covers the field \(field.frame)")
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
        mic.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the mic didn't raise the keyboard")
    }
}
