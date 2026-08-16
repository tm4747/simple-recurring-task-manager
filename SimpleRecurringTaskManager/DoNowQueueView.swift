//
//  DoNowQueueView.swift
//  SimpleRecurringTaskManager
//
//  Card-based queue shown by DoNowContainerView when more than one task is due at
//  once. Tapping a card hands the task to the container, which swaps in the full
//  Do Now action view for it.
//

import SwiftUI

struct DoNowQueueView: View {
    @Environment(\.theme) private var theme
    let tasks: [TaskItem]
    var onSelect: (TaskItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Due Now")
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(tasks) { task in
                        Button {
                            onSelect(task)
                        } label: {
                            card(for: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func card(for task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.primaryText)
            HStack {
                if let category = task.category {
                    Text(category.name)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Text(statusLabel(for: task))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.destructive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func statusLabel(for task: TaskItem) -> String {
        switch task.status {
        case .doingNow, .checkingNow:
            return "Time's Up"
        case .snoozed:
            return "Snooze Ended"
        default:
            return task.isOverdue ? "Overdue" : "Due Now"
        }
    }
}

#Preview {
    DoNowQueueView(tasks: [
        TaskItem(title: "Clean gutters", recurrenceType: .annually, firstOccurrence: Date()),
        TaskItem(title: "Change oil", recurrenceType: .byMileage, firstOccurrence: Date()),
    ]) { _ in }
        .environment(\.theme, .resolve(.light))
}
