import XCTest

/// Walks every tab in order and asserts each one actually renders.
///
/// This started life as a screenshot-capture scratch test during the visual
/// audit. The capture part is gone — it wrote PNGs into the simulator's
/// Documents directory, which is useless inside ephemeral UI-test clones — but
/// the walk itself is a genuine regression test: it fails if a tab never
/// appears, which is exactly the class of bug a retained `TabView` can cause.
final class VisualWalkUITests: XCTestCase {

    private let tabs = ["Home", "Find", "Crew", "Me"]

    func testCaptureEverySurface() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 20))

        for name in tabs {
            let button = app.tabBars.buttons[name]
            XCTAssertTrue(
                button.waitForExistence(timeout: 5),
                "Tab '\(name)' never appeared in the tab bar"
            )
            button.tap()
            // The point of the exercise: after switching, the screen must still
            // be alive and showing chrome. A blank or torn-down tab would drop
            // every static text on it.
            XCTAssertTrue(
                app.staticTexts.firstMatch.waitForExistence(timeout: 5),
                "Tab '\(name)' rendered no content after switching to it"
            )
        }
    }
}
