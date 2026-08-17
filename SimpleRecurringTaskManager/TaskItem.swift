//
//  TaskItem.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var category: Category?
    var car: Car?
    var isCheckFirst: Bool
    var recurrenceType: RecurrenceType

    // Recurrence-type-specific config. Only the fields relevant to `recurrenceType`
    // are ever read — see the PRD's "Recurrence Patterns" table for which fields
    // apply to which type.
    /// `nthWeekdayOfMonth`: 1-5, where 5 means "last".
    var recurrenceWeekNumber: Int?
    /// `nthWeekdayOfMonth`: 1-7 (1 = Sunday, matching `Calendar.Component.weekday`).
    var recurrenceWeekday: Int?
    /// `specificWeekdays`: 1-7 each, same convention as `recurrenceWeekday`.
    var recurrenceWeekdays: [Int]?

    var firstOccurrence: Date
    var nextDue: Date?
    var timeTakesToDo: TimeInterval?
    var timeTakesToCheck: TimeInterval?
    var mileageTrigger: Int?
    var timeTriggerMonths: Int?
    var isOverdue: Bool
    var status: TaskStatus
    var snoozeUntil: Date?
    var doingNowDeadline: Date?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TaskDoneItem.task)
    var doneItems: [TaskDoneItem] = []

    init(
        id: UUID = UUID(),
        title: String,
        category: Category? = nil,
        car: Car? = nil,
        isCheckFirst: Bool = false,
        recurrenceType: RecurrenceType,
        recurrenceWeekNumber: Int? = nil,
        recurrenceWeekday: Int? = nil,
        recurrenceWeekdays: [Int]? = nil,
        firstOccurrence: Date,
        nextDue: Date? = nil,
        timeTakesToDo: TimeInterval? = nil,
        timeTakesToCheck: TimeInterval? = nil,
        mileageTrigger: Int? = nil,
        timeTriggerMonths: Int? = nil,
        isOverdue: Bool = false,
        status: TaskStatus = .pending,
        snoozeUntil: Date? = nil,
        doingNowDeadline: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.car = car
        self.isCheckFirst = isCheckFirst
        self.recurrenceType = recurrenceType
        self.recurrenceWeekNumber = recurrenceWeekNumber
        self.recurrenceWeekday = recurrenceWeekday
        self.recurrenceWeekdays = recurrenceWeekdays
        self.firstOccurrence = firstOccurrence
        self.nextDue = nextDue
        self.timeTakesToDo = timeTakesToDo
        self.timeTakesToCheck = timeTakesToCheck
        self.mileageTrigger = mileageTrigger
        self.timeTriggerMonths = timeTriggerMonths
        self.isOverdue = isOverdue
        self.status = status
        self.snoozeUntil = snoozeUntil
        self.doingNowDeadline = doingNowDeadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TaskItem {
    /// True whenever this task currently needs a user decision — its next_due,
    /// snooze, or doing/checking-now countdown has passed. Drives both the
    /// foreground alarm trigger (ContentView) and the Do Now queue (Phase 8/9).
    var isDueForDecision: Bool {
        let now = Date()
        switch status {
        case .doingNow, .checkingNow:
            return (doingNowDeadline ?? .distantFuture) <= now
        case .snoozed:
            return (snoozeUntil ?? .distantFuture) <= now
        case .pending, .active, .deferred:
            // isOverdue is purely a display flag (red highlighting, per the
            // PRD — it persists until the task is marked Done) and must NOT
            // factor in here: deferTo()/snooze() both set it unconditionally
            // the moment they run, so treating it as "still due" would reopen
            // Do Now immediately after the user just deferred the task to a
            // legitimately future date. Only next_due having actually passed
            // means a decision is needed again.
            return nextDue.map { $0 <= now } ?? false
        }
    }
}
