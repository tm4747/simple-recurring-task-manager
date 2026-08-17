//
//  TaskCreationUITests.swift
//  SimpleRecurringTaskManagerUITests
//

import XCTest

final class TaskCreationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI-TESTING"]
        app.launch()
        return app
    }

    // A default first occurrence of "now" makes a freshly created task
    // immediately due, surfacing the Do Now flow on top of the list. Deferring
    // it via the plain "Do It This Evening" button (not one of the hold-for-menu
    // buttons, which XCUITest's synthetic tap doesn't reliably resolve to the tap
    // gesture over the long-press one) clears that without completing the task,
    // the same as a real user would, so the list row underneath becomes
    // reachable again.
    private func dismissDoNowIfPresented(_ app: XCUIApplication) {
        let deferButton = app.buttons["Do It This Evening"]
        guard deferButton.waitForExistence(timeout: 5) else { return }
        deferButton.tap()
        _ = deferButton.waitForNonExistence(timeout: 5)
    }

    func testCreatingATaskShowsItInTheList() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["TaskListView.NewTask"].waitForExistence(timeout: 5))
        app.buttons["TaskListView.NewTask"].tap()

        let titleField = app.textFields["Task Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Water plants")

        let createButton = app.buttons["Create Task"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        dismissDoNowIfPresented(app)

        let taskRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Water plants")).firstMatch
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No Tasks Yet"].exists)
    }

    func testCreateTaskButtonIsDisabledWithoutATitle() {
        let app = launchApp()
        app.buttons["TaskListView.NewTask"].tap()
        XCTAssertTrue(app.buttons["Create Task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Create Task"].isEnabled)
    }

    func testBackButtonDismissesTheFormWithoutCreatingATask() {
        let app = launchApp()
        app.buttons["TaskListView.NewTask"].tap()
        XCTAssertTrue(app.buttons["ScreenHeaderBar.Back"].waitForExistence(timeout: 5))
        app.buttons["ScreenHeaderBar.Back"].tap()

        XCTAssertTrue(app.staticTexts["No Tasks Yet"].waitForExistence(timeout: 5))
    }

    func testTappingAnExistingTaskOpensEditFormPrefilled() {
        let app = launchApp()
        app.buttons["TaskListView.NewTask"].tap()
        let titleField = app.textFields["Task Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Change air filter")
        app.buttons["Create Task"].tap()

        dismissDoNowIfPresented(app)

        let taskTitleText = app.staticTexts["Change air filter"]
        XCTAssertTrue(taskTitleText.waitForExistence(timeout: 5))
        taskTitleText.tap()

        XCTAssertTrue(app.staticTexts["Edit Task"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Task Title"].value as? String, "Change air filter")
    }

    // Unlike the default "Next Occurs" (which defaults to right now, making
    // a freshly created task immediately due), "Start Now" treats the task as
    // just completed and computes next_due from the recurrence cadence — so a
    // weekly task created this way should NOT immediately surface the Do Now
    // flow, and should show a future-dated row instead.
    func testStartNowScheduleBasisDoesNotMakeTheTaskImmediatelyDue() {
        let app = launchApp()
        app.buttons["TaskListView.NewTask"].tap()

        let titleField = app.textFields["Task Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Water plants")

        app.buttons["Start Now"].tap()
        app.buttons["Create Task"].tap()

        // No "Do It This Evening" (or any Do Now button) should ever appear —
        // give it a moment, then assert the list row directly.
        let deferButton = app.buttons["Do It This Evening"]
        XCTAssertFalse(deferButton.waitForExistence(timeout: 3))

        let taskRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Water plants")).firstMatch
        XCTAssertTrue(taskRow.waitForExistence(timeout: 5))
        // A real (non-nil) next_due confirms the weekly cadence actually ran
        // rather than the task silently ending up with no schedule at all.
        XCTAssertFalse(taskRow.label.localizedCaseInsensitiveContains("No due date"))
    }
}
