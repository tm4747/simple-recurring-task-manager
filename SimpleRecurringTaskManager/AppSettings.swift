//
//  AppSettings.swift
//  SimpleRecurringTaskManager
//

import Foundation
import SwiftData

/// A single row is seeded on first launch (see `DefaultDataSeeder`) and edited in
/// place thereafter — the app never creates a second instance.
@Model
final class AppSettings {
    var id: UUID
    var defaultSnoozeSeconds: Int
    /// Time-of-day only; the date components are meaningless and ignored everywhere
    /// this is read.
    var eveningTime: Date
    /// Time-of-day only, same convention as `eveningTime`.
    var weekendDefaultTime: Date
    var selectedTheme: String
    var alarmSound: String
    var alarmDurationSeconds: Int

    init(
        id: UUID = UUID(),
        defaultSnoozeSeconds: Int = 300,
        eveningTime: Date = AppSettings.time(hour: 18, minute: 0),
        weekendDefaultTime: Date = AppSettings.time(hour: 9, minute: 0),
        selectedTheme: String = "light",
        alarmSound: String = "default",
        alarmDurationSeconds: Int = 300
    ) {
        self.id = id
        self.defaultSnoozeSeconds = defaultSnoozeSeconds
        self.eveningTime = eveningTime
        self.weekendDefaultTime = weekendDefaultTime
        self.selectedTheme = selectedTheme
        self.alarmSound = alarmSound
        self.alarmDurationSeconds = alarmDurationSeconds
    }

    static func time(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

extension AppSettings {
    var theme: AppTheme {
        get { AppTheme(rawValue: selectedTheme) ?? .light }
        set { selectedTheme = newValue.rawValue }
    }
}

extension AppSettings {
    /// Returns the single AppSettings record, creating it if absent (mirrors
    /// DefaultDataSeeder's first-launch seed, as a fallback for call sites that run
    /// before or independently of it).
    static func shared(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor), let settings = existing.first {
            return settings
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
