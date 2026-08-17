//
//  SimpleRecurringTaskManagerUITests.swift
//  SimpleRecurringTaskManagerUITests
//
//  Launches with -UI-TESTING so SharedModelContainer uses an in-memory store
//  (see SharedModelContainer.isUITesting) — every run starts from the same
//  clean, deterministic, empty state instead of whatever real data happens to
//  already be in the shared App Group container.
//

import XCTest

final class SimpleRecurringTaskManagerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        return app
    }

    func testLaunchesToTasksTabWithEmptyState() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["Tasks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Tasks Yet"].waitForExistence(timeout: 5))
    }

    func testTabBarNavigatesBetweenAllThreeTabs() {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["No Tasks Yet"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Past Done"].tap()
        XCTAssertTrue(app.staticTexts["No Past Tasks"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Alarm"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Tasks"].tap()
        XCTAssertTrue(app.staticTexts["No Tasks Yet"].waitForExistence(timeout: 5))
    }

    func testThemeSwitchButtonCyclesThroughThemes() {
        let app = launchApp()
        let themeButton = app.buttons["Switch to Dark mode"]
        XCTAssertTrue(themeButton.waitForExistence(timeout: 5))
        themeButton.tap()

        // After one tap it should now offer to switch to Retro next.
        XCTAssertTrue(app.buttons["Switch to Retro mode"].waitForExistence(timeout: 5))
    }
}
