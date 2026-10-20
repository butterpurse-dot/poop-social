import XCTest

/// Diagnostic: answers "is onboarding presenting on a first run?" with an
/// assertion rather than a guess. Excluded from the main suite's contract but
/// runnable on demand.
final class LaunchProbeUITests: XCTestCase {

    func testOnboardingIsVisibleOnFirstRun() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 20))
        usleep(4_000_000)

        let hasTitle = app.staticTexts["Poop Social"].exists
        let hasTagline = app.staticTexts["No photos. Only vibes."].exists
        let tabCount = app.tabBars.count

        XCTAssertTrue(
            hasTitle || hasTagline,
            "onboarding not visible on first run (tabs=\(tabCount), texts=\(app.staticTexts.count))"
        )
    }
}
