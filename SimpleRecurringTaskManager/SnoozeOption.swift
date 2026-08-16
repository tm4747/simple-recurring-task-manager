//
//  SnoozeOption.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class SnoozeOption {
    var id: UUID
    var label: String
    var durationSeconds: Int
    var sortOrder: Int

    init(id: UUID = UUID(), label: String, durationSeconds: Int, sortOrder: Int) {
        self.id = id
        self.label = label
        self.durationSeconds = durationSeconds
        self.sortOrder = sortOrder
    }
}
