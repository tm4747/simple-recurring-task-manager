//
//  CategoryUITests.swift
//  SimpleRecurringTaskManagerUITests
//

import XCTest

final class CategoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        return app
    }

    func testCreatingACategoryMakesItSelectableInTheFilter() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["New Category"].waitForExistence(timeout: 5))
        app.buttons["New Category"].tap()

        let nameField = app.textFields["Category Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Yard Work")

        app.buttons["Save"].tap()

        // Creating a category auto-selects it as the active filter (see
        // NewCategoryView's onCreate callback in TaskListView), so the filter
        // menu's own label should already read "Yard Work" rather than "All".
        let filterButton = app.buttons["Yard Work"]
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))

        // Opening the menu should also still offer "All" to switch back.
        filterButton.tap()
        XCTAssertTrue(app.buttons["All"].waitForExistence(timeout: 5))
    }

    func testManageCategoriesShowsEmptyStateWithNoCategories() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["Manage Categories"].waitForExistence(timeout: 5))
        app.buttons["Manage Categories"].tap()

        XCTAssertTrue(app.staticTexts["No Categories Yet"].waitForExistence(timeout: 5))
    }
}
