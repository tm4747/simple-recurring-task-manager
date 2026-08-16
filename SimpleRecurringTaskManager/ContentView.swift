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
    @Query private var allTasks: [TaskItem]
    @Environment(\.scenePhase) private var scenePhase

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
        .task {
            _ = await NotificationScheduler.shared.requestAuthorization()
            NotificationScheduler.shared.registerCategories()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                playAlarmIfTaskDue()
            } else {
                AlarmPlayer.shared.stop()
            }
        }
    }

    // Foreground alarm trigger only — Phase 8 builds the Do Now view that
    // actually surfaces due tasks for the user to act on (and stops the alarm
    // when they do); this just makes sure the alarm sound itself starts playing
    // the moment a due task is noticed while the app is frontmost.
    private func playAlarmIfTaskDue() {
        let now = Date()
        guard allTasks.contains(where: { task in
            task.isOverdue || (task.nextDue.map { $0 <= now } ?? false)
        }) else { return }
        let settings = allSettings.first
        let sound = AlarmSound(rawValue: settings?.alarmSound ?? "default") ?? .systemDefault
        let duration = settings?.alarmDurationSeconds ?? 300
        AlarmPlayer.shared.play(sound: sound, durationSeconds: duration)
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
