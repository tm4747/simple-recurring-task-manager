//
//  TaskListView.swift
//  SimpleRecurringTaskManager
//
//  Phase 8 replaces the priority routing (Do Now takes over this tab when a task
//  is due) — this phase is the plain list: overdue-first, then grouped by
//  category, category-filterable, badge-synced.
//

import SwiftUI
import SwiftData
import UserNotifications

struct TaskListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query private var allTasks: [TaskItem]

    @State private var selectedCategory: Category?
    @State private var isShowingNewTask = false
    @State private var isShowingNewCategory = false
    @State private var isShowingManageCategories = false
    @State private var taskPendingEdit: TaskItem?
    @State private var taskPendingDelete: TaskItem?

    private var filteredTasks: [TaskItem] {
        guard let selectedCategory else { return allTasks }
        return allTasks.filter { $0.category?.persistentModelID == selectedCategory.persistentModelID }
    }

    private var overdueTasks: [TaskItem] {
        filteredTasks
            .filter(\.isOverdue)
            .sorted { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
    }

    private struct CategoryGroup: Identifiable {
        let category: Category?
        let tasks: [TaskItem]
        var id: PersistentIdentifier? { category?.persistentModelID }
        var name: String { category?.name ?? "Uncategorized" }
    }

    private var categoryGroups: [CategoryGroup] {
        let nonOverdue = filteredTasks.filter { !$0.isOverdue }
        let grouped = Dictionary(grouping: nonOverdue) { $0.category?.persistentModelID }
        return grouped
            .map { _, tasks in
                CategoryGroup(
                    category: tasks[0].category,
                    tasks: tasks.sorted { ($0.nextDue ?? .distantFuture) < ($1.nextDue ?? .distantFuture) }
                )
            }
            .sorted { $0.name < $1.name }
    }

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
            categoryFilterBar
            taskList
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingNewTask) {
            TaskFormView()
                .environment(\.theme, theme)
        }
        .sheet(item: $taskPendingEdit) { task in
            TaskFormView(taskToEdit: task)
                .environment(\.theme, theme)
        }
        .sheet(isPresented: $isShowingNewCategory) {
            NewCategoryView { category in
                selectedCategory = category
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $isShowingManageCategories) {
            ManageCategoriesView()
                .environment(\.theme, theme)
        }
        .confirmationDialog(
            "Delete This Task?",
            isPresented: Binding(
                get: { taskPendingDelete != nil },
                set: { if !$0 { taskPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: taskPendingDelete
        ) { task in
            Button("Delete", role: .destructive) {
                NotificationScheduler.shared.cancel(taskID: task.id)
                modelContext.delete(task)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This can't be undone.")
        }
        // The filtered-out category may have just been deleted elsewhere (e.g. from
        // ManageCategoriesView) — fall back to "All" rather than pointing at a
        // category that no longer exists.
        .onChange(of: categories) { _, newValue in
            if let selectedCategory, !newValue.contains(selectedCategory) {
                self.selectedCategory = nil
            }
        }
        .onAppear { updateBadge() }
        .onChange(of: allTasks) { _, _ in updateBadge() }
    }

    private var taskList: some View {
        Group {
            if filteredTasks.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Tasks Yet",
                    systemImage: "checklist",
                    description: Text("Tasks you create will show up here.")
                )
                Spacer()
            } else {
                List {
                    if !overdueTasks.isEmpty {
                        Section {
                            ForEach(overdueTasks) { task in
                                row(for: task)
                            }
                        } header: {
                            Text("Overdue")
                        }
                    }
                    ForEach(categoryGroups) { group in
                        Section {
                            ForEach(group.tasks) { task in
                                row(for: task)
                            }
                        } header: {
                            Text(group.name)
                        }
                    }
                }
                .themedFormChrome()
            }
        }
    }

    private var categoryFilterBar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("All") { selectedCategory = nil }
                ForEach(categories) { category in
                    Button(category.name) { selectedCategory = category }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCategory?.name ?? "All")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.primaryText)
            }

            Spacer()

            Button {
                isShowingManageCategories = true
            } label: {
                Image(systemName: "list.bullet")
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .accessibilityLabel("Manage Categories")

            Button {
                isShowingNewCategory = true
            } label: {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .accessibilityLabel("New Category")
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func row(for task: TaskItem) -> some View {
        Button {
            taskPendingEdit = task
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(theme.typography.headline)
                    .foregroundStyle(task.isOverdue ? theme.colors.destructive : theme.colors.primaryText)
                Text(rowSubtitle(for: task))
                    .font(theme.typography.caption)
                    .foregroundStyle(task.isOverdue ? theme.colors.destructive.opacity(0.8) : theme.colors.secondaryText)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            task.isOverdue ? theme.colors.destructive.opacity(0.12) : theme.colors.surface
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                taskPendingDelete = task
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func rowSubtitle(for task: TaskItem) -> String {
        var parts: [String] = []
        if let car = task.car {
            parts.append(car.name)
        }
        if let nextDue = task.nextDue {
            parts.append(nextDue.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.isEmpty ? "No due date" : parts.joined(separator: " • ")
    }

    private func updateBadge() {
        let now = Date()
        let dueCount = allTasks.filter { task in
            task.isOverdue || (task.nextDue.map { $0 <= now } ?? false)
        }.count
        UNUserNotificationCenter.current().setBadgeCount(dueCount)
    }
}

#Preview {
    TaskListView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskItem.self, Category.self, Car.self], inMemory: true)
}
