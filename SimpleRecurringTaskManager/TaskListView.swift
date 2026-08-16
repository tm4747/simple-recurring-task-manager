//
//  TaskListView.swift
//  SimpleRecurringTaskManager
//
//  Empty shell for the Tasks tab — Phase 5/6 add task creation and the real
//  sorted/grouped/filtered list. This phase only establishes the "+" button and
//  themed screen chrome.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.theme) private var theme
    @State private var isShowingNewTask = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Tasks") {
                Button {
                    isShowingNewTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
                .accessibilityLabel("New Task")
            }
            Spacer()
            ContentUnavailableView(
                "No Tasks Yet",
                systemImage: "checklist",
                description: Text("Tasks you create will show up here.")
            )
            Spacer()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingNewTask) {
            Text("New Task — coming soon")
                .environment(\.theme, theme)
        }
    }
}

#Preview {
    TaskListView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskItem.self, Category.self, Car.self], inMemory: true)
}
