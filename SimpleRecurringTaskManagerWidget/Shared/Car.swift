//
//  Car.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class Car {
    var id: UUID
    var name: String
    var initialMileage: Int?
    var monthlyMileageEstimate: Int?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MileageEntry.car)
    var mileageEntries: [MileageEntry] = []

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.car)
    var tasks: [TaskItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        initialMileage: Int? = nil,
        monthlyMileageEstimate: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialMileage = initialMileage
        self.monthlyMileageEstimate = monthlyMileageEstimate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
