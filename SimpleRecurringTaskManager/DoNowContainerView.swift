//
//  DoNowContainerView.swift
//  SimpleRecurringTaskManager
//
//  Presented full-screen by ContentView whenever any task isDueForDecision — the
//  PRD's priority routing. Shows the single-task Do Now view directly when only
//  one task needs a decision, otherwise the card queue; picking a card from the
//  queue drops into that task's Do Now view, and finishing it (which always
//  changes something that makes isDueForDecision false for that task) naturally
//  falls back to the queue on the next render, no manual "return to queue" wiring
//  needed.
//

import SwiftUI
import SwiftData

struct DoNowContainerView: View {
    @Environment(\.theme) private var theme
    @Query private var allTasks: [TaskItem]
    @Binding var isPresented: Bool
    @State private var selectedTask: TaskItem?

    private var dueTasks: [TaskItem] {
        allTasks
            .filter(\.isDueForDecision)
            .sorted { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
    }

    var body: some View {
        Group {
            if dueTasks.isEmpty {
                Color.clear
            } else if let selectedTask, dueTasks.contains(where: { $0.persistentModelID == selectedTask.persistentModelID }) {
                DoNowView(task: selectedTask, showBackButton: dueTasks.count > 1) {
                    self.selectedTask = nil
                }
            } else if dueTasks.count == 1 {
                DoNowView(task: dueTasks[0])
            } else {
                DoNowQueueView(tasks: dueTasks) { task in
                    selectedTask = task
                }
            }
        }
        .environment(\.theme, theme)
        .onChange(of: dueTasks.isEmpty) { _, isEmpty in
            if isEmpty {
                isPresented = false
            }
        }
    }
}
