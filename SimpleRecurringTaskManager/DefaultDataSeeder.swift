//
//  DefaultDataSeeder.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

enum DefaultDataSeeder {
    static let carMaintenanceCategoryName = "Car Maintenance"

    /// Seeds the system "Car Maintenance" category on a fresh install, i.e. when it
    /// doesn't already exist.
    @discardableResult
    static func seedCarMaintenanceCategoryIfNeeded(context: ModelContext) -> Category? {
        let name = carMaintenanceCategoryName
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == name })
        guard (try? context.fetchCount(descriptor)) == 0 else { return nil }

        let category = Category(name: carMaintenanceCategoryName, isSystem: true)
        context.insert(category)
        return category
    }

    /// Seeds the default snooze options on a fresh install, i.e. when none exist yet.
    static func seedDefaultSnoozeOptionsIfNeeded(context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<SnoozeOption>())) == 0 else { return }

        let defaults: [(label: String, seconds: Int)] = [
            ("5 minutes", 5 * 60),
            ("30 minutes", 30 * 60),
            ("1 hour", 60 * 60),
            ("3 hours", 3 * 60 * 60),
        ]
        for (index, option) in defaults.enumerated() {
            context.insert(SnoozeOption(label: option.label, durationSeconds: option.seconds, sortOrder: index))
        }
    }

    /// Seeds the single `AppSettings` row on a fresh install, i.e. when it doesn't
    /// already exist.
    @discardableResult
    static func seedAppSettingsIfNeeded(context: ModelContext) -> AppSettings? {
        guard (try? context.fetchCount(FetchDescriptor<AppSettings>())) == 0 else { return nil }

        let settings = AppSettings()
        context.insert(settings)
        return settings
    }

    static func seedAllIfNeeded(context: ModelContext) {
        seedCarMaintenanceCategoryIfNeeded(context: context)
        seedDefaultSnoozeOptionsIfNeeded(context: context)
        seedAppSettingsIfNeeded(context: context)
    }
}
