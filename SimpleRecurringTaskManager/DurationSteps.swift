//
//  DurationSteps.swift
//  SimpleTimer
//
//  A fixed, explicit list of selectable durations (in seconds), used by the
//  Settings steppers: Duration default, Default Snooze Duration, and the 4
//  Snooze Options all pick from this same list.
//

import Foundation

enum DurationSteps {
    static let values: [Int] = [
        15, 30, 45,                                   // 15/30/45 sec
        60, 120, 180, 240, 300,                        // 1/2/3/4/5 min
        600, 900, 1200, 1500, 1800,                     // 10/15/20/25/30 min
        2400, 3000,                                     // 40/50 min
        3600, 4500, 5400, 6300,                          // 1 hr, 1:15, 1:30, 1:45
        7200, 9000,                                      // 2 hr, 2:30
        10800, 12600,                                     // 3 hr, 3:30
        14400, 16200,                                     // 4 hr, 4:30
        18000, 21600, 25200, 28800, 32400, 36000,         // 5/6/7/8/9/10 hr
        45000,                                            // 12:30
        54000, 72000,                                     // 15/20 hr
        86400, 129600, 172800, 259200                     // 24/36/48/72 hr
    ]

    /// Steps from the nearest listed value to `current` in `direction` (>0 for up,
    /// <0 for down), skipping any value present in `excluding` — used so the 4
    /// configurable snooze options can't be stepped onto a duplicate of each other.
    /// Clamps at the ends of the list rather than wrapping.
    static func step(from current: Int, direction: Int, excluding: Set<Int> = []) -> Int {
        guard !values.isEmpty else { return current }
        let startIndex = nearestIndex(to: current)
        let delta = direction >= 0 ? 1 : -1
        var index = startIndex + delta

        while values.indices.contains(index) {
            let candidate = values[index]
            if !excluding.contains(candidate) { return candidate }
            index += delta
        }
        // Ran off the end without finding a non-excluded value — hold at the
        // nearest valid (non-excluded) value instead of stepping.
        let nearest = values[startIndex]
        return excluding.contains(nearest) ? (values.first(where: { !excluding.contains($0) }) ?? nearest) : nearest
    }

    private static func nearestIndex(to value: Int) -> Int {
        if let exact = values.firstIndex(of: value) { return exact }
        var closest = 0
        var smallestDiff = Int.max
        for (i, v) in values.enumerated() {
            let diff = abs(v - value)
            if diff < smallestDiff {
                smallestDiff = diff
                closest = i
            }
        }
        return closest
    }
}
