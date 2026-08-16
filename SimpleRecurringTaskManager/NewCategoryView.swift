//
//  NewCategoryView.swift
//  SimpleRecurringTaskManager
//
//  Reached from the "+" next to the Tasks tab's category filter, and (Phase 5)
//  from a "+" next to the category dropdown on the task form.
//

import SwiftUI
import SwiftData

struct NewCategoryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allTasks: [TaskItem]
    @FocusState private var isNameFocused: Bool

    @State private var name = ""
    @State private var selectedTaskIDs: Set<PersistentIdentifier> = []

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
            }
            .themedFormChrome()

            Button("Save") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trimmedName.isEmpty)
                .padding()
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
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

    private func toggle(_ task: TaskItem) {
        if selectedTaskIDs.contains(task.persistentModelID) {
            selectedTaskIDs.remove(task.persistentModelID)
        } else {
            selectedTaskIDs.insert(task.persistentModelID)
        }
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
