//
//  TaskDoneItem.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class TaskDoneItem {
    var id: UUID
    var task: TaskItem?
    var completedAt: Date
    /// true = the work was actually performed; false = a check-first task was
    /// checked and determined not to need doing.
    var wasDone: Bool
    var note: String?
    var mileageAtCompletion: Int?
    /// Snapshot of `task.isOverdue` (negated) at the moment of completion — needed
    /// for streak calculation (PRD: "a completion counts as on time if the task
    /// was not marked overdue when completed"), since the live TaskItem.isOverdue
    /// flag gets reset right after each completion and can't be read back
    /// retroactively. Defaults true on the declaration so lightweight migration
    /// backfills existing rows sensibly if this field is ever added after data
    /// already exists.
    var wasOnTime: Bool = true

    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        completedAt: Date = Date(),
        wasDone: Bool,
        note: String? = nil,
        mileageAtCompletion: Int? = nil,
        wasOnTime: Bool = true
    ) {
        self.id = id
        self.task = task
        self.completedAt = completedAt
        self.wasDone = wasDone
        self.note = note
        self.mileageAtCompletion = mileageAtCompletion
        self.wasOnTime = wasOnTime
    }
}
