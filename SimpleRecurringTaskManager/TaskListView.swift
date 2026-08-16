//
//  TaskListView.swift
//  SimpleRecurringTaskManager
//
//  Phase 6 adds the real sorted/grouped/filtered task list — this phase adds the
//  category filter, category management entry points, and the "+" new-task button.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Category.createdAt) private var categories: [Category]

    @State private var selectedCategory: Category?
    @State private var isShowingNewTask = false
    @State private var isShowingNewCategory = false
    @State private var isShowingManageCategories = false

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
            TaskFormView()
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
        // The filtered-out category may have just been deleted elsewhere (e.g. from
        // ManageCategoriesView) — fall back to "All" rather than pointing at a
        // category that no longer exists.
        .onChange(of: categories) { _, newValue in
            if let selectedCategory, !newValue.contains(selectedCategory) {
                self.selectedCategory = nil
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
}

#Preview {
    TaskListView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [TaskItem.self, Category.self, Car.self], inMemory: true)
}
