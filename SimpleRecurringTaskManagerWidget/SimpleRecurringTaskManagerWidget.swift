//
//  SimpleRecurringTaskManagerWidget.swift
//  SimpleRecurringTaskManagerWidget
//
//  Shows the next 3 upcoming tasks (title + time until due), reading the same
//  SwiftData store as the main app via the shared App Group container (see
//  Shared/SharedModelContainer.swift). Each row deep-links back into the app via
//  the simplerecurringtaskmanager:// URL scheme, handled in ContentView.
//

import WidgetKit
import SwiftUI
import SwiftData

struct UpcomingTaskInfo: Identifiable {
    let id: UUID
    let title: String
    let nextDue: Date
}

struct UpcomingTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [UpcomingTaskInfo]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingTasksEntry {
        UpcomingTasksEntry(date: Date(), tasks: [
            UpcomingTaskInfo(id: UUID(), title: "Change oil", nextDue: Date().addingTimeInterval(3600)),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingTasksEntry) -> Void) {
        completion(UpcomingTasksEntry(date: Date(), tasks: fetchUpcomingTasks()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingTasksEntry>) -> Void) {
        let entry = UpcomingTasksEntry(date: Date(), tasks: fetchUpcomingTasks())
        // The app also calls WidgetCenter.reloadAllTimelines() after every task
        // mutation, so this periodic refresh is just a fallback for the passage
        // of time itself (a "due in 2 hours" row reading stale otherwise).
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func fetchUpcomingTasks() -> [UpcomingTaskInfo] {
        let context = ModelContext(SharedModelContainer.make())
        guard let allTasks = try? context.fetch(FetchDescriptor<TaskItem>()) else { return [] }
        let now = Date()
        return allTasks
            .compactMap { task -> (TaskItem, Date)? in
                guard let due = task.nextDue, due >= now else { return nil }
                return (task, due)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map { UpcomingTaskInfo(id: $0.0.id, title: $0.0.title, nextDue: $0.1) }
    }
}

struct SimpleRecurringTaskManagerWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Tasks")
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.tasks.isEmpty {
                Spacer()
                Text("No Upcoming Tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.tasks) { task in
                    Link(destination: deepLinkURL(for: task)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Text(task.nextDue, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func deepLinkURL(for task: UpcomingTaskInfo) -> URL {
        URL(string: "simplerecurringtaskmanager://task/\(task.id.uuidString)")
            ?? URL(string: "simplerecurringtaskmanager://")!
    }
}

struct SimpleRecurringTaskManagerWidget: Widget {
    let kind = "SimpleRecurringTaskManagerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SimpleRecurringTaskManagerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Tasks")
        .description("Shows your next 3 upcoming tasks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    SimpleRecurringTaskManagerWidget()
} timeline: {
    UpcomingTasksEntry(date: .now, tasks: [
        UpcomingTaskInfo(id: UUID(), title: "Change oil", nextDue: Date().addingTimeInterval(3600)),
        UpcomingTaskInfo(id: UUID(), title: "Clean gutters", nextDue: Date().addingTimeInterval(86400)),
    ])
}
