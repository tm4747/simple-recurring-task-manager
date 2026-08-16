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

    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        completedAt: Date = Date(),
        wasDone: Bool,
        note: String? = nil,
        mileageAtCompletion: Int? = nil
    ) {
        self.id = id
        self.task = task
        self.completedAt = completedAt
        self.wasDone = wasDone
        self.note = note
        self.mileageAtCompletion = mileageAtCompletion
    }
}
