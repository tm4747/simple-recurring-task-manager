//
//  RecurrenceEngineTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
@testable import SimpleRecurringTaskManager

struct RecurrenceEngineTests {
    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test func neverCompletedTaskKeepsExactlyItsEnteredFirstOccurrence() {
        let firstOccurrence = date(2026, 9, 15)
        let task = TaskItem(title: "Water plants", recurrenceType: .weekly, firstOccurrence: firstOccurrence)
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == firstOccurrence)
    }

    @Test func weeklyStepsSevenDaysFromLastCompletion() {
        let task = TaskItem(title: "Water plants", recurrenceType: .weekly, firstOccurrence: date(2026, 9, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 9, 15), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 9, 22))
    }

    @Test func dailyStepsOneDayFromLastCompletion() {
        let task = TaskItem(title: "Take medicine", recurrenceType: .daily, firstOccurrence: date(2026, 9, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 9, 10), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 9, 11))
    }

    @Test func biweeklyStepsFourteenDays() {
        let task = TaskItem(title: "Mow lawn", recurrenceType: .biweekly, firstOccurrence: date(2026, 9, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 9, 1), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 9, 15))
    }

    @Test func monthlyStepsOneCalendarMonth() {
        let task = TaskItem(title: "Pay rent", recurrenceType: .monthly, firstOccurrence: date(2026, 1, 31))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 1, 31), wasDone: true)]
        // Calendar.date(byAdding: .month, value: 1, to: Jan 31) clamps to the last
        // valid day of February — this asserts we inherit that (correct) behavior
        // rather than crashing or silently overflowing into March.
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 2, 28))
    }

    @Test func biannuallyStepsSixMonths() {
        let task = TaskItem(title: "HVAC filter", recurrenceType: .biannually, firstOccurrence: date(2026, 1, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 1, 1), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 7, 1))
    }

    @Test func annuallyStepsOneYear() {
        let task = TaskItem(title: "Smoke detector battery", recurrenceType: .annually, firstOccurrence: date(2026, 3, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 3, 1), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2027, 3, 1))
    }

    @Test func oneTimeTaskHasNoNextDueAfterCompletion() {
        let task = TaskItem(title: "Renew passport", recurrenceType: .oneTime, firstOccurrence: date(2026, 5, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 5, 1), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == nil)
    }

    @Test func firstOfMonthAdvancesToNextMonthWhenAlreadyPastThisMonths() {
        let task = TaskItem(title: "Budget review", recurrenceType: .firstOfMonth, firstOccurrence: date(2026, 1, 1))
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 6, 15), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 7, 1, 9, 0))
    }

    @Test func nthWeekdayOfMonthFindsThirdWednesday() {
        let task = TaskItem(
            title: "Team meeting",
            recurrenceType: .nthWeekdayOfMonth,
            firstOccurrence: date(2026, 1, 1)
        )
        task.recurrenceWeekNumber = 3
        task.recurrenceWeekday = 4 // Wednesday
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 3, 1), wasDone: true)]
        let next = RecurrenceEngine.recalculatedNextDue(for: task)
        #expect(next != nil)
        if let next {
            #expect(calendar.component(.weekday, from: next) == 4)
            #expect(calendar.component(.month, from: next) == 3)
            // The 3rd Wednesday of March 2026 is the 18th.
            #expect(calendar.component(.day, from: next) == 18)
        }
    }

    @Test func nthWeekdayOfMonthLastMeansLastOccurrenceEvenWhenOnlyFourExist() {
        let task = TaskItem(
            title: "Payroll",
            recurrenceType: .nthWeekdayOfMonth,
            firstOccurrence: date(2026, 1, 1)
        )
        task.recurrenceWeekNumber = 5 // "Last"
        task.recurrenceWeekday = 6 // Friday
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 1, 1), wasDone: true)]
        let next = RecurrenceEngine.recalculatedNextDue(for: task)
        #expect(next != nil)
        if let next {
            #expect(calendar.component(.weekday, from: next) == 6)
            // The next Friday-of-a-month occurrence must be strictly after Jan 1.
            #expect(next > date(2026, 1, 1))
        }
    }

    @Test func specificWeekdaysFindsSoonestMatchingWeekday() {
        let task = TaskItem(
            title: "Take out trash",
            recurrenceType: .specificWeekdays,
            firstOccurrence: date(2026, 1, 1)
        )
        task.recurrenceWeekdays = [2, 5] // Monday, Thursday
        // 2026-09-14 is a Monday.
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 9, 14), wasDone: true)]
        let next = RecurrenceEngine.recalculatedNextDue(for: task)
        #expect(next != nil)
        if let next {
            let weekday = calendar.component(.weekday, from: next)
            #expect(weekday == 5) // the next Thursday, not the following Monday
        }
    }

    @Test func byMileageTaskIsLeftAloneByRecurrenceEngine() {
        // RecurrenceEngine explicitly defers byMileage tasks to MileageEngine —
        // it should return whatever next_due already is, unchanged.
        let task = TaskItem(title: "Oil change", recurrenceType: .byMileage, firstOccurrence: date(2026, 1, 1))
        task.nextDue = date(2026, 6, 1)
        task.doneItems = [TaskDoneItem(task: task, completedAt: date(2026, 1, 1), wasDone: true)]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 6, 1))
    }

    @Test func recalculationAnchorsToMostRecentCompletionNotOriginalDueDate() {
        // "Recurring task completed early" edge case from the PRD: completing
        // ahead of schedule shifts the cycle forward from the completion date,
        // not the originally-scheduled date.
        let task = TaskItem(title: "Water plants", recurrenceType: .weekly, firstOccurrence: date(2026, 9, 1))
        task.doneItems = [
            TaskDoneItem(task: task, completedAt: date(2026, 9, 1), wasDone: true),
            TaskDoneItem(task: task, completedAt: date(2026, 9, 5), wasDone: true), // completed early
        ]
        #expect(RecurrenceEngine.recalculatedNextDue(for: task) == date(2026, 9, 12))
    }
}
