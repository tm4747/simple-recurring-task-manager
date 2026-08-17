//
//  TaskItemTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
@testable import SimpleRecurringTaskManager

struct TaskItemTests {
    private func makeTask(status: TaskStatus = .pending) -> TaskItem {
        TaskItem(title: "Test", recurrenceType: .weekly, firstOccurrence: Date(), status: status)
    }

    @Test func pendingTaskIsDueWhenNextDueIsInThePast() {
        let task = makeTask()
        task.nextDue = Date().addingTimeInterval(-3600)
        #expect(task.isDueForDecision)
    }

    @Test func pendingTaskIsNotDueWhenNextDueIsInTheFuture() {
        let task = makeTask()
        task.nextDue = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)
    }

    // isOverdue is a display-only flag (red highlighting) — deferTo()/snooze()
    // both set it unconditionally the instant they run, so it must NOT also
    // make the task due again immediately, or deferring/snoozing to a
    // legitimately future date would just reopen Do Now right away.
    @Test func pendingTaskIsNotDueFromIsOverdueAloneWithFutureNextDue() {
        let task = makeTask()
        task.nextDue = Date().addingTimeInterval(3600)
        task.isOverdue = true
        #expect(!task.isDueForDecision)
    }

    @Test func pendingTaskWithNoNextDueIsNotDue() {
        let task = makeTask()
        task.nextDue = nil
        #expect(!task.isDueForDecision)
    }

    @Test func snoozedTaskIsDueOnlyAfterSnoozeUntilPasses() {
        let task = makeTask(status: .snoozed)
        task.snoozeUntil = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)

        task.snoozeUntil = Date().addingTimeInterval(-1)
        #expect(task.isDueForDecision)
    }

    @Test func snoozedTaskIgnoresNextDueEntirely() {
        // Even if next_due is in the past, a still-active snooze should suppress
        // isDueForDecision — snooze_until is what matters while status == .snoozed.
        let task = makeTask(status: .snoozed)
        task.nextDue = Date().addingTimeInterval(-3600)
        task.snoozeUntil = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)
    }

    @Test func doingNowTaskIsDueOnlyAfterDeadlinePasses() {
        let task = makeTask(status: .doingNow)
        task.doingNowDeadline = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)

        task.doingNowDeadline = Date().addingTimeInterval(-1)
        #expect(task.isDueForDecision)
    }

    @Test func checkingNowTaskIsDueOnlyAfterDeadlinePasses() {
        let task = makeTask(status: .checkingNow)
        task.doingNowDeadline = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)

        task.doingNowDeadline = Date().addingTimeInterval(-1)
        #expect(task.isDueForDecision)
    }

    @Test func deferredTaskBehavesLikePendingAgainstNextDue() {
        let task = makeTask(status: .deferred)
        task.isOverdue = true // deferTo() always sets this; must not affect the result.
        task.nextDue = Date().addingTimeInterval(-3600)
        #expect(task.isDueForDecision)

        task.nextDue = Date().addingTimeInterval(3600)
        #expect(!task.isDueForDecision)
    }
}
