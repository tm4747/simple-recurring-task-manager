//
//  AppTheme.swift
//  SimpleTimer
//
//  The user-selectable theme identity. Persisted as UserSettings.themeRawValue;
//  everything about how a theme actually looks lives in ThemeTokens.swift.
//

import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case retro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .retro: return "Retro"
        }
    }
}
