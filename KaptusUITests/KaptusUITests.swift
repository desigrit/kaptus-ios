import XCTest

final class KaptusUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor
    func testHomeSettingsAndSamplePlayer() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["home.find"].waitForExistence(timeout: 15))
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.secureTextFields["settings.apiKey"].waitForExistence(timeout: 5))
        app.buttons["settings.done"].tap()
        app.buttons["home.sample"].tap()
        XCTAssertTrue(app.staticTexts["player.caption"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["player.caption"].label.contains("new story"))
        app.buttons["player.advance"].tap()
        XCTAssertEqual(app.staticTexts["player.offset"].label, "Caption adjustment +0.5 seconds")
        app.buttons["player.play"].tap()
        XCTAssertTrue(app.buttons["player.play"].label.contains("Play"))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["player.caption"].exists)
        XCTAssertTrue(app.buttons["player.play"].label.contains("Play"))
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        Thread.sleep(forTimeInterval: 1)
        let captionFrame = app.staticTexts["player.caption"].frame
        XCTAssertGreaterThanOrEqual(captionFrame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(captionFrame.maxX, app.frame.maxX)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "player-landscape"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["player.settings"].tap()
        XCTAssertTrue(app.navigationBars["Player settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["player.close"].tap()
        XCTAssertTrue(app.buttons["home.find"].waitForExistence(timeout: 5))
    }
    @MainActor
    func testControlsHideAndRevealWithoutLosingCaptions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-demo-player"]
        app.launch()
        XCTAssertTrue(app.staticTexts["player.caption"].waitForExistence(timeout: 10))
        if !app.buttons["player.play"].exists { app.staticTexts["player.caption"].tap() }
        XCTAssertTrue(app.buttons["player.play"].waitForExistence(timeout: 2))
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["player.play"])
        waitForExpectations(timeout: 7)
        XCTAssertTrue(app.staticTexts["player.caption"].exists)
        app.staticTexts["player.caption"].tap()
        XCTAssertTrue(app.buttons["player.play"].waitForExistence(timeout: 2))
    }
    @MainActor
    func testAccessibilityTextSizeAndSearchSetup() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["home.find"].waitForExistence(timeout: 10))
        app.buttons["home.find"].tap()
        XCTAssertTrue(app.navigationBars["Find your story"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !app.buttons["search.setup"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["search.setup"].isHittable)
        for _ in 0..<2 where !app.buttons["search.import"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["search.import"].isHittable)
    }
}
