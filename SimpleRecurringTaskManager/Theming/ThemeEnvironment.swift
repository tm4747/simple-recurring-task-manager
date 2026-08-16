//
//  ThemeEnvironment.swift
//  SimpleTimer
//
//  Exposes the resolved Theme through the SwiftUI environment. ContentView is
//  the single place that resolves AppTheme -> Theme from UserSettings; every
//  other view just reads @Environment(\.theme).
//

import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .resolve(.light)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
