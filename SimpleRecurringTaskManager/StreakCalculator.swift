//
//  StreakCalculator.swift
//  SimpleRecurringTaskManager
//

import Foundation

enum StreakCalculator {
    /// Consecutive on-time completions counting back from the most recent — breaks
    /// the moment a completion where `wasOnTime == false` is hit.
    static func currentStreak(for task: TaskItem) -> Int {
        let sorted = task.doneItems.sorted { $0.completedAt > $1.completedAt }
        var streak = 0
        for item in sorted {
            guard item.wasOnTime else { break }
            streak += 1
        }
        return streak
    }
}
