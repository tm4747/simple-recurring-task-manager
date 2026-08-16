//
//  MileageEngine.swift
//  SimpleRecurringTaskManager
//
//  Mileage estimation and the by-mileage next_due calculation. RecurrenceEngine
//  deliberately leaves byMileage tasks alone ("Phase 10 owns this calculation") —
//  this is that owner.
//

import Foundation
import SwiftData

enum MileageEngine {
    private static let daysPerMonth = 30.44

    /// Miles/month — from real data once 2+ entries exist (straight line between
    /// the earliest and latest), otherwise the user's initial estimate.
    static func monthlyAverage(for car: Car) -> Double {
        let entries = car.mileageEntries.sorted { $0.recordedAt < $1.recordedAt }
        guard entries.count >= 2, let first = entries.first, let last = entries.last else {
            return Double(car.monthlyMileageEstimate ?? 0)
        }
        let months = monthsBetween(first.recordedAt, last.recordedAt)
        guard months > 0 else { return Double(car.monthlyMileageEstimate ?? 0) }
        return Double(last.mileage - first.mileage) / months
    }

    /// `estimated_current_mileage = last_entered_mileage + (months_since_entry × monthly_average)`.
    static func estimatedCurrentMileage(for car: Car, asOf date: Date = Date()) -> Int? {
        guard let lastEntry = car.mileageEntries.max(by: { $0.recordedAt < $1.recordedAt }) else {
            return car.initialMileage
        }
        let average = monthlyAverage(for: car)
        let monthsSince = monthsBetween(lastEntry.recordedAt, date)
        return Int((Double(lastEntry.mileage) + monthsSince * average).rounded())
    }

    /// Recalculates next_due for a byMileage task: the estimated date its mileage
    /// trigger will be reached, or its time trigger's date, whichever is sooner if
    /// both are set.
    static func recalculatedNextDue(for task: TaskItem, car: Car, asOf now: Date = Date()) -> Date? {
        guard task.recurrenceType == .byMileage else { return task.nextDue }

        var mileageDate: Date?
        if let mileageTrigger = task.mileageTrigger {
            let referenceMileage = task.doneItems.compactMap(\.mileageAtCompletion).max() ?? car.initialMileage ?? 0
            let targetMileage = referenceMileage + mileageTrigger
            let currentEstimate = estimatedCurrentMileage(for: car, asOf: now) ?? referenceMileage
            let average = monthlyAverage(for: car)
            if average > 0 {
                let monthsRemaining = Double(targetMileage - currentEstimate) / average
                let daysRemaining = Int((monthsRemaining * daysPerMonth).rounded())
                mileageDate = Calendar.current.date(byAdding: .day, value: daysRemaining, to: now)
            }
        }

        var timeDate: Date?
        if let months = task.timeTriggerMonths {
            let anchor = task.doneItems.map(\.completedAt).max() ?? task.firstOccurrence
            timeDate = Calendar.current.date(byAdding: .month, value: months, to: anchor)
        }

        switch (mileageDate, timeDate) {
        case let (m?, t?): return min(m, t)
        case let (m?, nil): return m
        case let (nil, t?): return t
        case (nil, nil): return task.firstOccurrence
        }
    }

    /// Per the PRD's per-car prompting schedule: monthly for the first 3 months,
    /// bimonthly for months 4-9, quarterly from month 10 on. `monthIndex` 1 is the
    /// car's creation month.
    static func isPromptDue(for car: Car, asOf date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let monthsSinceCreation = calendar.dateComponents([.month], from: car.createdAt, to: date).month ?? 0
        let monthIndex = monthsSinceCreation + 1

        let isScheduledMonth: Bool
        switch monthIndex {
        case 1...3: isScheduledMonth = true
        case 4...9: isScheduledMonth = monthIndex.isMultiple(of: 2)
        default: isScheduledMonth = (monthIndex - 10).isMultiple(of: 3)
        }
        guard isScheduledMonth else { return false }

        // Already answered this calendar month — don't ask again.
        return !car.mileageEntries.contains { calendar.isDate($0.recordedAt, equalTo: date, toGranularity: .month) }
    }

    /// Backfills a system-estimated entry (linear interpolation between the
    /// previous real entry and this new one) for each calendar month in between
    /// that has no entry of its own — the PRD's "system-estimated entries...
    /// created for non-prompted months".
    static func backfillEstimatedEntries(for car: Car, through newEntry: MileageEntry, context: ModelContext) {
        let priorEntries = car.mileageEntries
            .filter { $0.persistentModelID != newEntry.persistentModelID && $0.recordedAt < newEntry.recordedAt }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard let previous = priorEntries.last else { return }

        let calendar = Calendar.current
        let totalMonths = calendar.dateComponents([.month], from: previous.recordedAt, to: newEntry.recordedAt).month ?? 0
        guard totalMonths > 1 else { return }

        let mileagePerMonth = Double(newEntry.mileage - previous.mileage) / Double(totalMonths)
        for offset in 1..<totalMonths {
            guard let entryDate = calendar.date(byAdding: .month, value: offset, to: previous.recordedAt) else { continue }
            let hasEntry = car.mileageEntries.contains { calendar.isDate($0.recordedAt, equalTo: entryDate, toGranularity: .month) }
            guard !hasEntry else { continue }
            let estimatedMileage = Int((Double(previous.mileage) + Double(offset) * mileagePerMonth).rounded())
            context.insert(MileageEntry(car: car, mileage: estimatedMileage, recordedAt: entryDate, isUserEntered: false))
        }
    }

    static func monthsBetween(_ start: Date, _ end: Date) -> Double {
        end.timeIntervalSince(start) / (daysPerMonth * 24 * 3600)
    }
}
