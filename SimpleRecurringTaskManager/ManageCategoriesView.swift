//
//  ManageCategoriesView.swift
//  SimpleRecurringTaskManager
//
//  Deletion surface for user-created categories, reached from the Tasks tab.
//  The system "Car Maintenance" category never appears here — it's
//  non-deletable, so there's nothing this screen could do with it.
//

import SwiftUI
import SwiftData

struct ManageCategoriesView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.createdAt) private var allCategories: [Category]
    @State private var categoryPendingDelete: Category?

    private var deletableCategories: [Category] {
        allCategories.filter { !$0.isSystem }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(title: "Manage Categories", onBack: { dismiss() })
            List {
                ForEach(deletableCategories) { category in
                    HStack {
                        Text(category.name).foregroundStyle(theme.colors.primaryText)
                        Spacer()
                        Text("\(category.tasks.count)")
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                    .listRowBackground(theme.colors.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            categoryPendingDelete = category
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .themedFormChrome()
            .overlay {
                if deletableCategories.isEmpty {
                    ContentUnavailableView(
                        "No Categories Yet",
                        systemImage: "folder",
                        description: Text("Categories you create will show up here.")
                    )
                }
            }
        }
        .themedScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
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
}

#Preview {
    ManageCategoriesView()
        .environment(\.theme, .resolve(.light))
        .modelContainer(for: [Category.self, TaskItem.self], inMemory: true)
}
