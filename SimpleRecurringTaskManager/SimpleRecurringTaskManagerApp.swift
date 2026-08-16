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
    var sharedModelContainer: ModelContainer = SharedModelContainer.make()

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
