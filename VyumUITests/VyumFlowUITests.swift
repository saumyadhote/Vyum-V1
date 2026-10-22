import XCTest

/// Walks the main journeys through real taps. Screenshots are attached to the
/// test results, and also written to `VYUM_SCREENSHOT_DIR` when that is set.
@MainActor
final class VyumFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingReset"]
        app.launch()
    }

    func testOnboardingThenCompleteSingleExercise() throws {
        snapshot("01-onboarding-welcome")
        completeOnboarding(selecting: ["neck", "upperBack"])

        XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 5), "Home should show a start button")
        snapshot("05-today")

        // Library → exercise detail → try it now.
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.staticTexts["Guided sessions"].waitForExistence(timeout: 5))
        snapshot("06-library")

        // The catalogue is a lazy list: scroll until the exercise row is on screen.
        let shoulderRolls = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Shoulder Rolls'")).firstMatch
        for _ in 0..<6 where !shoulderRolls.isHittable { app.swipeUp() }
        XCTAssertTrue(shoulderRolls.waitForExistence(timeout: 5))
        shoulderRolls.tap()
        XCTAssertTrue(app.buttons["exercise.tryNow"].waitForExistence(timeout: 5))
        snapshot("07-exercise-detail")

        app.buttons["exercise.tryNow"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5))
        snapshot("08-session-get-ready")

        app.buttons["session.startNow"].tap()
        sleep(2)
        snapshot("09-session-active")

        // Pause and resume.
        app.buttons["session.pauseResume"].tap()
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Resume")
        snapshot("10-session-paused")
        app.buttons["session.pauseResume"].tap()
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Pause")

        // Let the 40-second exercise finish naturally.
        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 60), "Session should complete")
        XCTAssertTrue(app.staticTexts["Session complete"].exists)
        snapshot("11-session-complete")
        app.buttons["session.done"].tap()

        // Progress shows mock weekly data with a streak.
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["4-day streak"].waitForExistence(timeout: 5))
        snapshot("12-progress")

        // Posture check. The Simulator has no camera, so it explains that instead.
        app.tabBars.buttons["Posture"].tap()
        XCTAssertTrue(app.staticTexts["Stand in the frame"].waitForExistence(timeout: 5))
        snapshot("20-posture")
    }

    func testEndSessionEarlyAndSearch() throws {
        completeOnboarding(selecting: [])

        XCTAssertTrue(app.buttons["today.start"].waitForExistence(timeout: 5))
        app.buttons["today.start"].tap()
        XCTAssertTrue(app.buttons["session.skip"].waitForExistence(timeout: 5))

        app.buttons["session.skip"].tap()
        XCTAssertTrue(app.staticTexts["Exercise 2 of"].exists || app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Exercise 2 of'")).firstMatch.exists)

        // Cancelling keeps the session going.
        app.buttons["session.close"].tap()
        let alert = app.alerts["End this session?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Ending should ask for confirmation")
        snapshot("13-end-confirmation")
        alert.buttons["Keep going"].tap()
        XCTAssertTrue(app.buttons["session.skip"].waitForExistence(timeout: 5))

        app.buttons["session.close"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["End session"].tap()

        XCTAssertTrue(app.buttons["session.done"].waitForExistence(timeout: 5))
        snapshot("14-ended-early")
        app.buttons["session.done"].tap()

        // Progress shows sample data for now, with weekly and monthly views.
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["This week"].waitForExistence(timeout: 5))
        snapshot("15-progress-weekly")
        app.segmentedControls["progress.period"].buttons["Posture Analysis"].tap()
        XCTAssertTrue(app.staticTexts["What we noticed"].waitForExistence(timeout: 5))
        snapshot("15b-posture-analysis")

        // Search with no results shows a helpful empty state.
        app.tabBars.buttons["Exercises"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("trampoline")
        XCTAssertTrue(app.staticTexts["No matching exercises"].waitForExistence(timeout: 5))
        snapshot("16-search-empty")
        app.buttons["Clear search and filters"].tap()

        search.tap()
        search.typeText("hip")
        XCTAssertTrue(app.staticTexts["1 exercise"].waitForExistence(timeout: 5))
        snapshot("17-search-results")
    }

    func testInterruptedSessionCanBeResumed() throws {
        completeOnboarding(selecting: [])
        app.buttons["today.start"].tap()
        XCTAssertTrue(app.buttons["session.startNow"].waitForExistence(timeout: 5))
        app.buttons["session.startNow"].tap()
        sleep(2)

        // Leave the app; the session pauses and saves.
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Relaunch without resetting state.
        app.terminate()
        app.launchArguments = []
        app.launch()

        XCTAssertTrue(app.buttons["today.resume"].waitForExistence(timeout: 5), "Home should offer to resume")
        snapshot("18-today-resume")
        app.buttons["today.resume"].tap()
        XCTAssertTrue(app.buttons["session.pauseResume"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["session.pauseResume"].label, "Resume", "A resumed session starts paused")
        snapshot("19-session-resumed")
    }

    // MARK: - Helpers

    private func completeOnboarding(selecting areas: [String]) {
        XCTAssertTrue(app.buttons["onboarding.start"].waitForExistence(timeout: 10), "Onboarding should appear on first launch")
        app.buttons["onboarding.start"].tap()

        for area in areas {
            app.buttons["onboarding.focus.\(area)"].tap()
        }
        snapshot("02-onboarding-focus")
        app.buttons["onboarding.continue"].tap()
        snapshot("03-onboarding-preferences")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.skipReminder"].waitForExistence(timeout: 5))
        snapshot("04-onboarding-reminder")
        app.buttons["onboarding.skipReminder"].tap()
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let directory = ProcessInfo.processInfo.environment["VYUM_SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
