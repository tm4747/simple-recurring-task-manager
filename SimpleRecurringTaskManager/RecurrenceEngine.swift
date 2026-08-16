//
//  RecurrenceEngine.swift
//  SimpleRecurringTaskManager
//
//  Computes a TaskItem's next_due. Per the PRD: if the task has never been
//  completed, next_due is exactly what the user entered as firstOccurrence — it
//  only starts stepping forward by the recurrence cadence once anchored to a real
//  TaskDoneItem.completedAt. by_mileage tasks are left alone here; Phase 10 owns
//  their next_due (it's driven by estimated mileage, not a calendar cadence).
//

import Foundation

enum RecurrenceEngine {
    static func recalculatedNextDue(for task: TaskItem) -> Date? {
        guard let lastCompletion = task.doneItems.map(\.completedAt).max() else {
            return task.firstOccurrence
        }
        switch task.recurrenceType {
        case .oneTime:
            return nil
        case .byMileage:
            return task.nextDue
        default:
            return nextOccurrence(after: lastCompletion, task: task)
        }
    }

    private static func nextOccurrence(after anchor: Date, task: TaskItem) -> Date? {
        let calendar = Calendar.current
        switch task.recurrenceType {
        case .oneTime, .byMileage:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: anchor)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: anchor)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: anchor)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: anchor)
        case .biannually:
            return calendar.date(byAdding: .month, value: 6, to: anchor)
        case .annually:
            return calendar.date(byAdding: .year, value: 1, to: anchor)
        case .firstOfMonth:
            return nextFirstOfMonth(after: anchor)
        case .nthWeekdayOfMonth:
            return nextNthWeekday(
                after: anchor,
                weekNumber: task.recurrenceWeekNumber ?? 1,
                weekday: task.recurrenceWeekday ?? 1
            )
        case .specificWeekdays:
            return nextSpecificWeekday(after: anchor, weekdays: task.recurrenceWeekdays ?? [])
        }
    }

    private static func nextFirstOfMonth(after date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .hour, .minute], from: date)
        components.day = 1
        guard let thisMonthFirst = calendar.date(from: components) else { return nil }
        if thisMonthFirst > date { return thisMonthFirst }
        return calendar.date(byAdding: .month, value: 1, to: thisMonthFirst)
    }

    /// `weekNumber` is 1-5, where 5 means "last" (however many of `weekday` that
    /// month actually has, whether 4 or 5).
    private static func nextNthWeekday(after date: Date, weekNumber: Int, weekday: Int) -> Date? {
        let calendar = Calendar.current
        var monthCursor = date
        // 24-month bound: generous enough for any real nth-weekday cadence (even a
        // "5th Friday" that only lands ~4x/year) without risking an infinite loop.
        for _ in 0..<24 {
            if let candidate = nthWeekday(weekNumber: weekNumber, weekday: weekday, in: monthCursor, time: date),
               candidate > date {
                return candidate
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
            monthCursor = next
        }
        return nil
    }

    private static func nthWeekday(weekNumber: Int, weekday: Int, in monthDate: Date, time: Date) -> Date? {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var monthComponents = calendar.dateComponents([.year, .month], from: monthDate)
        monthComponents.day = 1
        guard let firstOfMonth = calendar.date(from: monthComponents),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }

        var matches: [Date] = []
        for day in range {
            var dayComponents = monthComponents
            dayComponents.day = day
            guard let candidate = calendar.date(from: dayComponents) else { continue }
            if calendar.component(.weekday, from: candidate) == weekday {
                matches.append(candidate)
            }
        }
        guard !matches.isEmpty else { return nil }
        let index = weekNumber == 5 ? matches.count - 1 : weekNumber - 1
        guard matches.indices.contains(index) else { return nil }

        var resultComponents = calendar.dateComponents([.year, .month, .day], from: matches[index])
        resultComponents.hour = timeComponents.hour
        resultComponents.minute = timeComponents.minute
        return calendar.date(from: resultComponents)
    }

    private static func nextSpecificWeekday(after date: Date, weekdays: [Int]) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let calendar = Calendar.current
        for offset in 1...14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if weekdays.contains(calendar.component(.weekday, from: candidate)) {
                return candidate
            }
        }
        return nil
    }
}
