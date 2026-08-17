//
//  NewCategoryView.swift
//  SimpleRecurringTaskManager
//
//  Reached from the "+" next to the Tasks tab's category filter, and (Phase 5)
//  from a "+" next to the category dropdown on the task form. Also doubles as
//  the category management surface — the "Existing Categories" list below the
//  new-category form supports the standard iOS swipe-to-edit/delete.
//

import SwiftUI
import SwiftData

struct NewCategoryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TaskItem]
    @Query(sort: \Category.createdAt) private var allCategories: [Category]
    @FocusState private var isNameFocused: Bool

    @State private var name = ""
    @State private var selectedTaskIDs: Set<PersistentIdentifier> = []
    @State private var categoryPendingDelete: Category?
    @State private var categoryPendingRename: Category?
    @State private var renameText = ""

    /// When creating from the task form's inline "+", the caller passes this to
    /// receive the new category and pre-select it — see the PRD's "Creating a
    /// category from the New/Edit Task view" flow.
    var onCreate: ((Category) -> Void)?

    private var uncategorizedTasks: [TaskItem] {
        allTasks.filter { $0.category == nil }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The system "Car Maintenance" category never appears here — it's
    // non-deletable/non-renamable, so there's nothing this list could do with it.
    private var editableCategories: [Category] {
        allCategories.filter { !$0.isSystem }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "New Category", onBack: { dismiss() })
            Form {
                Section {
                    SpokenLabelField(text: $name, placeholder: "Category Name", isFocused: $isNameFocused)
                        .listRowBackground(theme.colors.surface)
                } header: {
                    Text("Name")
                }

                if !uncategorizedTasks.isEmpty {
                    Section {
                        ForEach(uncategorizedTasks) { task in
                            taskRow(task)
                        }
                    } header: {
                        Text("Assign Uncategorized Tasks")
                    }
                }

                Section {
                    if editableCategories.isEmpty {
                        Text("No categories yet.")
                            .foregroundStyle(theme.colors.secondaryText)
                            .listRowBackground(theme.colors.surface)
                    } else {
                        ForEach(editableCategories) { category in
                            existingCategoryRow(category)
                        }
                    }
                } header: {
                    Text("Existing Categories")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.primaryText)
                        .textCase(nil)
                }
            }
            .themedFormChrome()

            Button("Save") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
                .padding()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .alert(
            "Rename Category",
            isPresented: Binding(
                get: { categoryPendingRename != nil },
                set: { if !$0 { categoryPendingRename = nil } }
            )
        ) {
            TextField("Category Name", text: $renameText)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) { categoryPendingRename = nil }
        }
        .confirmationDialog(
            "Delete This Category?",
            isPresented: Binding(
                get: { categoryPendingDelete != nil },
                set: { if !$0 { categoryPendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: categoryPendingDelete
        ) { category in
            Button("Delete", role: .destructive) {
                modelContext.delete(category)
            }
            Button("Cancel", role: .cancel) {}
        } message: { category in
            Text("\(category.tasks.count) task\(category.tasks.count == 1 ? "" : "s") will become uncategorized. This can't be undone.")
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            toggle(task)
        } label: {
            HStack {
                Text(task.title).foregroundStyle(theme.colors.primaryText)
                Spacer()
                if selectedTaskIDs.contains(task.persistentModelID) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.colors.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(theme.colors.surface)
    }

    private func existingCategoryRow(_ category: Category) -> some View {
        HStack {
            Text(category.name).foregroundStyle(theme.colors.primaryText)
            Spacer()
            Text("\(category.tasks.count)")
                .foregroundStyle(theme.colors.secondaryText)
        }
        .listRowBackground(theme.colors.surface)
        .swipeActions(edge: .trailing) {
            // For .trailing swipe actions, the LAST-declared button ends up
            // closest to the row content (leftmost of the revealed pair) and
            // the FIRST-declared one sits flush against the true screen edge —
            // so Delete is declared first to land on the right, Edit second to
            // land on the left.
            Button(role: .destructive) {
                categoryPendingDelete = category
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)

            Button {
                renameText = category.name
                categoryPendingRename = category
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func toggle(_ task: TaskItem) {
        if selectedTaskIDs.contains(task.persistentModelID) {
            selectedTaskIDs.remove(task.persistentModelID)
        } else {
            selectedTaskIDs.insert(task.persistentModelID)
        }
    }

    private func commitRename() {
        defer { categoryPendingRename = nil }
        guard let category = categoryPendingRename else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        category.name = trimmed
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let category = Category(name: trimmedName)
        modelContext.insert(category)
        for task in uncategorizedTasks where selectedTaskIDs.contains(task.persistentModelID) {
            task.category = category
        }
        onCreate?(category)
        dismiss()
    }
}

#Preview {
    NewCategoryView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [Category.self, TaskItem.self], inMemory: true)
}
