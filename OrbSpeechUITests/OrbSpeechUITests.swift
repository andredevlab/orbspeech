import XCTest

final class OrbSpeechUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws { }

    @MainActor
    func testInitialControlsRequirePreparation() throws {
        let app = XCUIApplication()
        app.launch()

        let statusAfterLaunch = app.staticTexts["orb-status"]
        XCTAssertTrue(statusAfterLaunch.waitForExistence(timeout: 10))
        XCTAssertEqual(statusAfterLaunch.label, "idle")

        let prepareButton = app.buttons["Prepare Components"]
        XCTAssertTrue(prepareButton.waitForExistence(timeout: 5))
        XCTAssertTrue(prepareButton.isEnabled)
        XCTAssertTrue(prepareButton.isHittable)

        let talkButton = app.buttons["Talk"]
        XCTAssertTrue(talkButton.waitForExistence(timeout: 5))
        XCTAssertFalse(talkButton.isEnabled)
        XCTAssertFalse(app.buttons["Stop"].exists)
        XCTAssertFalse(app.buttons["All set"].exists)
    }

    @MainActor
    func testMoveLeftAudioFixtureCompletesCommand() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--orb-ui-test-audio-fixture"]
        app.launchEnvironment["ORB_UI_TEST_AUDIO_RESOURCE"] = "move_left"
        app.launchEnvironment["ORB_UI_TEST_TRANSCRIPT"] = "move left"
        app.launch()

        let statusAfterLaunch = app.staticTexts["orb-status"]
        XCTAssertTrue(statusAfterLaunch.waitForExistence(timeout: 10))
        XCTAssertEqual(statusAfterLaunch.label, "idle")

        let prepareButton = app.buttons["Prepare Components"]
        XCTAssertTrue(prepareButton.waitForExistence(timeout: 5))
        prepareButton.tap()

        let allSetButton = app.buttons["All set"]
        XCTAssertTrue(allSetButton.waitForExistence(timeout: 10))

        let talkButton = app.buttons["Talk"]
        XCTAssertTrue(talkButton.waitForExistence(timeout: 5))
        talkButton.tap()

        let statusAfterTalk = waitForStatus(app,
                                            matching: NSPredicate(format: "label BEGINSWITH %@", "Listening - voice level:"),
                                            timeout: 5)
        XCTAssertTrue(statusAfterTalk.hasPrefix("Listening - voice level:"))

        // status during command
        _ = waitForStatus(app,
                          matching: NSPredicate(format: "label == %@", "Acting"),
                          timeout: 15)

        let statusAfterCommand = waitForStatus(app,
                                               matching: NSPredicate(format: "label BEGINSWITH %@", "Listening - voice level:"),
                                               timeout: 5)
        XCTAssertTrue(statusAfterCommand.hasPrefix("Listening - voice level:"))
    }

    @MainActor
    private func waitForStatus(_ app: XCUIApplication,
                               matching predicate: NSPredicate,
                               timeout: TimeInterval,
                               file: StaticString = #filePath,
                               line: UInt = #line) -> String {
        let status = app.staticTexts["orb-status"]
        XCTAssertTrue(status.waitForExistence(timeout: timeout), file: file, line: line)

        let deadline = Date().addingTimeInterval(timeout)
        var lastLabel = status.label

        while Date() < deadline {
            lastLabel = status.label
            if predicate.evaluate(with: status) {
                return lastLabel
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail("Current status: \(lastLabel)", file: file, line: line)
        return lastLabel
    }
}
