//
//  SimpleRecurringTaskManagerApp.swift
//  SimpleRecurringTaskManager
//
//  Created by Tom Molinaro on 8/16/26.
//

import SwiftUI
import SwiftData

@main
struct SimpleRecurringTaskManagerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Car.self,
            MileageEntry.self,
            Category.self,
            TaskItem.self,
            TaskDoneItem.self,
            SnoozeOption.self,
            AppSettings.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        DefaultDataSeeder.seedAllIfNeeded(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
