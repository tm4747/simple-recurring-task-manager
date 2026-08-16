//
//  TimeFormatting.swift
//  SimpleTimer
//

import Foundation

extension Int {
    var formattedAsTimer: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // Natural-language duration for settings rows (e.g. snooze options), where a
    // compact "MM:SS" reads less clearly than "5 min" or "1 hr 30 min".
    var formattedAsDuration: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hr") }
        if m > 0 { parts.append("\(m) min") }
        if s > 0 { parts.append("\(s) sec") }
        return parts.isEmpty ? "0 sec" : parts.joined(separator: " ")
    }
}
