//
//  ContentView.swift
//  SimpleRecurringTaskManager
//
//  Created by Tom Molinaro on 8/16/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Single place theme resolution happens; every other view just reads
    // @Environment(\.theme). Falls back to .light if AppSettings hasn't been
    // created yet (matches Theme's own default) — mirrors ../SimpleTimer's
    // ContentView pattern.
    @Query private var allSettings: [AppSettings]
    private var currentTheme: Theme {
        Theme.resolve(allSettings.first?.theme ?? .light)
    }

    var body: some View {
        TabView {
            TaskListView()
                .tabItem { Label("Tasks", systemImage: "checklist") }

            PastDoneView()
                .tabItem { Label("Past Done", systemImage: "clock.arrow.circlepath") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(currentTheme.colors.accent)
        .environment(\.theme, currentTheme)
        .preferredColorScheme(currentTheme.appTheme == .light ? .light : .dark)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Car.self,
            MileageEntry.self,
            Category.self,
            TaskItem.self,
            TaskDoneItem.self,
            SnoozeOption.self,
            AppSettings.self,
        ], inMemory: true)
}
