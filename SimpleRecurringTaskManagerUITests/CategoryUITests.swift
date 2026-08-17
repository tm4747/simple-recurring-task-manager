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

    func testNewCategoryViewShowsNoCategoriesTextWhenNoneExist() {
        let app = launchApp()
        app.buttons["New Category"].tap()

        XCTAssertTrue(app.staticTexts["No categories yet."].waitForExistence(timeout: 5))
    }

    func testExistingCategoriesListShowsRenamedAndDeletedCategories() {
        let app = launchApp()
        app.buttons["New Category"].tap()

        let nameField = app.textFields["Category Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Yard Work")
        app.buttons["Save"].tap()

        // Saving dismisses back to the Tasks list — reopen New Category to see
        // "Yard Work" listed under Existing Categories. Saving also auto-selects
        // the new category as the Tasks tab's filter, so its label now reads
        // "Yard Work" too — scoping to `cells` (the Existing Categories list row,
        // unlike the filter button) is what keeps the query unambiguous.
        app.buttons["New Category"].tap()
        XCTAssertTrue(app.staticTexts["Existing Categories"].waitForExistence(timeout: 5))
        let categoryText = app.cells.staticTexts["Yard Work"]
        XCTAssertTrue(categoryText.waitForExistence(timeout: 5))

        categoryText.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5)) // confirmation dialog
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["No categories yet."].waitForExistence(timeout: 5))
    }
}
