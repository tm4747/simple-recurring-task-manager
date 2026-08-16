//
//  MileageEntry.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

@Model
final class MileageEntry {
    var id: UUID
    var car: Car?
    var mileage: Int
    var recordedAt: Date
    var isUserEntered: Bool

    init(
        id: UUID = UUID(),
        car: Car? = nil,
        mileage: Int,
        recordedAt: Date = Date(),
        isUserEntered: Bool
    ) {
        self.id = id
        self.car = car
        self.mileage = mileage
        self.recordedAt = recordedAt
        self.isUserEntered = isUserEntered
    }
}
