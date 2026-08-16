//
//  Category.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var isSystem: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.category)
    var tasks: [TaskItem] = []

    init(id: UUID = UUID(), name: String, isSystem: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.isSystem = isSystem
        self.createdAt = createdAt
    }
}
