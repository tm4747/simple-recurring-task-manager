//
//  RecurrenceType.swift
//  SimpleRecurringTaskManager
//

import Foundation

enum RecurrenceType: String, Codable, CaseIterable {
    case oneTime = "one_time"
    case daily
    case weekly
    case biweekly
    case monthly
    case biannually
    case annually
    case firstOfMonth = "first_of_month"
    case nthWeekdayOfMonth = "nth_weekday_of_month"
    case specificWeekdays = "specific_weekdays"
    case byMileage = "by_mileage"
}
