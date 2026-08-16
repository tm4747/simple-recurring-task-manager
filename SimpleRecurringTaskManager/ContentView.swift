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
    @State private var isShowingDoNow = false

    private var currentTheme: Theme {
        Theme.resolve(allSettings.first?.theme ?? .light)
    }

    private var dueTasks: [TaskItem] {
        allTasks.filter(\.isDueForDecision)
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
        .fullScreenCover(isPresented: $isShowingDoNow) {
            DoNowContainerView(isPresented: $isShowingDoNow)
                .environment(\.theme, currentTheme)
        }
        .task {
            _ = await NotificationScheduler.shared.requestAuthorization()
            NotificationScheduler.shared.registerCategories()
        }
        // Due tasks are computed from wall-clock time, not just data changes, so a
        // task can become due while the app just sits open — this periodic
        // re-check is what surfaces the Do Now flow and alarm in that case, not
        // just on data mutation or a background/foreground transition.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                refreshDueState()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshDueState()
            } else {
                AlarmPlayer.shared.stop()
            }
        }
        .onChange(of: allTasks) { _, _ in refreshDueState() }
        .onAppear { refreshDueState() }
    }

    private func refreshDueState() {
        guard !dueTasks.isEmpty else { return }
        isShowingDoNow = true
        let settings = allSettings.first
        let sound = AlarmSound(rawValue: settings?.alarmSound ?? "default") ?? .systemDefault
        let duration = settings?.alarmDurationSeconds ?? 300
        AlarmPlayer.shared.playIfNeeded(sound: sound, durationSeconds: duration)
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
