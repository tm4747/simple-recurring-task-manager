//
//  StreakCalculatorTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
@testable import SimpleRecurringTaskManager

struct StreakCalculatorTests {
    private func date(_ daysAgo: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(-daysAgo * 86400))
    }

    @Test func zeroForATaskWithNoCompletions() {
        let task = TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date())
        #expect(StreakCalculator.currentStreak(for: task) == 0)
    }

    @Test func countsAllCompletionsWhenAllOnTime() {
        let task = TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date())
        task.doneItems = [
            TaskDoneItem(task: task, completedAt: date(30), wasDone: true, wasOnTime: true),
            TaskDoneItem(task: task, completedAt: date(20), wasDone: true, wasOnTime: true),
            TaskDoneItem(task: task, completedAt: date(10), wasDone: true, wasOnTime: true),
        ]
        #expect(StreakCalculator.currentStreak(for: task) == 3)
    }

    @Test func breaksAtTheMostRecentLateCompletion() {
        let task = TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date())
        task.doneItems = [
            TaskDoneItem(task: task, completedAt: date(30), wasDone: true, wasOnTime: true),
            TaskDoneItem(task: task, completedAt: date(20), wasDone: true, wasOnTime: false), // late
            TaskDoneItem(task: task, completedAt: date(10), wasDone: true, wasOnTime: true),
        ]
        // Counting back from most recent: date(10) on-time, then date(20) breaks it.
        #expect(StreakCalculator.currentStreak(for: task) == 1)
    }

    @Test func isOrderIndependentInTheDoneItemsArray() {
        let task = TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date())
        // Deliberately out of chronological order.
        task.doneItems = [
            TaskDoneItem(task: task, completedAt: date(10), wasDone: true, wasOnTime: true),
            TaskDoneItem(task: task, completedAt: date(30), wasDone: true, wasOnTime: true),
            TaskDoneItem(task: task, completedAt: date(20), wasDone: true, wasOnTime: true),
        ]
        #expect(StreakCalculator.currentStreak(for: task) == 3)
    }
}
