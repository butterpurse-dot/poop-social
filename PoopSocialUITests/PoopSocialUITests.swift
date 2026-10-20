import XCTest

/// End-to-end UI verification for poop social.
///
/// Drives every root tab, the composer and the hygiene screen so a green run
/// means the app actually rendered and responded — not merely that it
/// compiled. Launch arguments let the app skip onboarding so the tests always
/// start on a known screen.
final class PoopSocialUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.waitForExistence(timeout: 20), "app did not stay running")
    }

    // MARK: - Helpers

    /// Taps a root tab by its visible label.
    private func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "tab \(label) not found")
        tab.tap()
    }

    /// Waits for at least one drawn element, which distinguishes a rendered
    /// screen from an empty one.
    @discardableResult
    private func waitForContent(_ note: String, timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts.count > 0 || app.buttons.count > 6 { return true }
            usleep(200_000)
        }
        XCTFail("\(note) rendered nothing")
        return false
    }

    // MARK: - Tests

    func testLaunchesWithFiveTabs() throws {
        let tabs = app.tabBars.buttons
        XCTAssertEqual(tabs.count, 5, "expected exactly five root tabs")

        for label in ["Home", "Reels", "Find", "Crew", "Me"] {
            XCTAssertTrue(tabs[label].exists, "missing tab: \(label)")
        }
        waitForContent("Home after launch")
    }

    func testEveryTabRenders() throws {
        for label in ["Home", "Reels", "Find", "Crew", "Me"] {
            tapTab(label)
            waitForContent("\(label) tab")
        }
    }

    func testComposerOpens() throws {
        tapTab("Home")

        let compose = app.buttons["composeButton"]
        XCTAssertTrue(compose.waitForExistence(timeout: 5), "compose button not found")
        compose.tap()

        // A presented sheet must expose an input surface.
        let deadline = Date().addingTimeInterval(6)
        var hasInput = false
        while Date() < deadline {
            if app.textViews.count > 0 || app.textFields.count > 0 { hasInput = true; break }
            usleep(200_000)
        }
        XCTAssertTrue(hasInput, "composer sheet opened without any text input")
    }

    func testHygieneScreenOpens() throws {
        tapTab("Me")

        let card = app.buttons["hygieneCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "hygiene card not found")
        card.tap()
        waitForContent("hygiene sheet")
    }

    func testSurvivesFullNavigation() throws {
        // Visit every tab twice to exercise lazy view construction.
        for _ in 0..<2 {
            for label in ["Home", "Reels", "Find", "Crew", "Me"] {
                tapTab(label)
                usleep(350_000)
            }
        }
        XCTAssertEqual(app.state, .runningForeground,
                       "app left the foreground during navigation")
    }
}
