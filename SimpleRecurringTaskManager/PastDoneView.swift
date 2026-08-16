//
//  PastDoneView.swift
//  SimpleRecurringTaskManager
//
//  Mirrors ../SimpleBoxingTimer's PastWorkoutsView grouping: the current
//  calendar month's entries show individually, the rest of the current year
//  collapses into one expandable group per month, and prior years each collapse
//  into a single expandable group. Only one group open at a time.
//

import SwiftUI
import SwiftData

struct PastDoneView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \TaskDoneItem.completedAt, order: .reverse) private var entries: [TaskDoneItem]

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    private enum ExpandedGroup: Hashable {
        case month(MonthKey)
        case year(Int)
    }

    @State private var expandedGroup: ExpandedGroup?

    private var calendar: Calendar { Calendar.current }
    private var currentYear: Int { calendar.component(.year, from: Date()) }
    private var currentMonth: Int { calendar.component(.month, from: Date()) }

    private var currentMonthEntries: [TaskDoneItem] {
        entries.filter {
            let comps = calendar.dateComponents([.year, .month], from: $0.completedAt)
            return comps.year == currentYear && comps.month == currentMonth
        }
    }

    private var monthGroups: [(key: MonthKey, entries: [TaskDoneItem])] {
        let filtered = entries.filter {
            let comps = calendar.dateComponents([.year, .month], from: $0.completedAt)
            return comps.year == currentYear && comps.month != currentMonth
        }
        let grouped = Dictionary(grouping: filtered) { entry in
            let comps = calendar.dateComponents([.year, .month], from: entry.completedAt)
            return MonthKey(year: comps.year!, month: comps.month!)
        }
        return grouped
            .map { (key: $0.key, entries: $0.value) }
            .sorted { $0.key.month > $1.key.month }
    }

    private var yearGroups: [(year: Int, entries: [TaskDoneItem])] {
        let filtered = entries.filter { calendar.component(.year, from: $0.completedAt) != currentYear }
        let grouped = Dictionary(grouping: filtered) { calendar.component(.year, from: $0.completedAt) }
        return grouped
            .map { (year: $0.key, entries: $0.value) }
            .sorted { $0.year > $1.year }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Past Done")
            historyList
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var historyList: some View {
        List {
            Section {
                ForEach(currentMonthEntries) { entry in
                    row(for: entry)
                }
            }

            ForEach(monthGroups, id: \.key) { group in
                Section {
                    if expandedGroup == .month(group.key) {
                        ForEach(group.entries) { entry in
                            row(for: entry)
                        }
                    }
                } header: {
                    groupHeader(
                        label: "\(monthYear(group.entries[0].completedAt)) - \(countLabel(group.entries.count))",
                        isExpanded: expandedGroup == .month(group.key)
                    ) {
                        toggle(.month(group.key))
                    }
                }
            }

            ForEach(yearGroups, id: \.year) { group in
                Section {
                    if expandedGroup == .year(group.year) {
                        ForEach(group.entries) { entry in
                            row(for: entry)
                        }
                    }
                } header: {
                    groupHeader(
                        label: "\(String(group.year)) - \(countLabel(group.entries.count))",
                        isExpanded: expandedGroup == .year(group.year)
                    ) {
                        toggle(.year(group.year))
                    }
                }
            }
        }
        .themedFormChrome()
        .overlay {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Past Tasks",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Tasks you complete will show up here.")
                )
            }
        }
    }

    private func row(for entry: TaskDoneItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.task?.title ?? "Deleted Task")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.primaryText)
                Spacer()
                Text(entry.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            HStack(spacing: 6) {
                if let category = entry.task?.category?.name {
                    Text(category)
                }
                if entry.task?.isCheckFirst == true {
                    Text(entry.wasDone ? "Done" : "Checked — Not Needed")
                }
                if let mileage = entry.mileageAtCompletion {
                    Text("\(mileage) mi")
                }
                if let task = entry.task {
                    let streak = StreakCalculator.currentStreak(for: task)
                    if streak >= 2 {
                        Text("\(streak) in a row on time")
                    }
                }
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.secondaryText)

            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(theme.colors.surface)
    }

    @ViewBuilder
    private func groupHeader(label: String, isExpanded: Bool, onToggle: @escaping () -> Void) -> some View {
        Button {
            onToggle()
        } label: {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ group: ExpandedGroup) {
        withAnimation(.easeInOut(duration: 0.25)) {
            expandedGroup = (expandedGroup == group) ? nil : group
        }
    }

    private func countLabel(_ count: Int) -> String {
        "\(count) task\(count == 1 ? "" : "s")"
    }

    private func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

#Preview {
    PastDoneView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskDoneItem.self, TaskItem.self], inMemory: true)
}
