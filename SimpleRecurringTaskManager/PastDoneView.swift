//
//  PastDoneView.swift
//  SimpleRecurringTaskManager
//
//  Empty shell for the Past Done tab — Phase 11 adds the real month/year-grouped
//  history list (matching ../SimpleBoxingTimer's Past Workouts pattern).
//

import SwiftUI
import SwiftData

struct PastDoneView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Past Done")
            Spacer()
            ContentUnavailableView(
                "No Past Tasks",
                systemImage: "clock.arrow.circlepath",
                description: Text("Tasks you complete will show up here.")
            )
            Spacer()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    PastDoneView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskDoneItem.self], inMemory: true)
}
