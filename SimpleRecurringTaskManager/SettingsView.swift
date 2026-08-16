//
//  SettingsView.swift
//  SimpleRecurringTaskManager
//
//  Empty shell for the Settings tab — Phase 3 adds the full Alarm / Snooze /
//  Defer Defaults / Appearance / Widget / Cars sections.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Settings")
            Spacer()
            Text("Settings coming soon")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [AppSettings.self], inMemory: true)
}
