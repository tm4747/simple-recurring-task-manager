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
    /// Unlike `eveningTime`, the weekday component here is meaningful — it's
    /// either Saturday or Sunday (see `AppSettings.nextWeekday`), since "this
    /// weekend" spans a Sat 6 AM – Sun 9 PM window rather than a single time of
    /// day. The specific calendar day encoded is whichever was nearest when it was
    /// last set; only its weekday and time-of-day are ever read.
    var weekendDefaultTime: Date
    var selectedTheme: String
    var alarmSound: String
    var alarmDurationSeconds: Int
    var widgetEnabled: Bool

    init(
        id: UUID = UUID(),
        defaultSnoozeSeconds: Int = 300,
        eveningTime: Date = AppSettings.time(hour: 18, minute: 0),
        weekendDefaultTime: Date = AppSettings.nextWeekday(.saturday, hour: 9, minute: 0),
        selectedTheme: String = "light",
        alarmSound: String = "default",
        alarmDurationSeconds: Int = 300,
        widgetEnabled: Bool = true
    ) {
        self.id = id
        self.defaultSnoozeSeconds = defaultSnoozeSeconds
        self.eveningTime = eveningTime
        self.weekendDefaultTime = weekendDefaultTime
        self.selectedTheme = selectedTheme
        self.alarmSound = alarmSound
        self.alarmDurationSeconds = alarmDurationSeconds
        self.widgetEnabled = widgetEnabled
    }

    static func time(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    enum WeekendDay: Int {
        case saturday = 7
        case sunday = 1
    }

    /// The nearest date (today or later) falling on `weekday`, at the given time.
    static func nextWeekday(_ weekday: WeekendDay, hour: Int, minute: Int, from reference: Date = Date()) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: reference)
        let daysUntil = (weekday.rawValue - currentWeekday + 7) % 7
        let targetDay = calendar.date(byAdding: .day, value: daysUntil, to: reference) ?? reference
        var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? reference
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
