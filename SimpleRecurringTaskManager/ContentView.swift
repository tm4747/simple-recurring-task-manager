//
//  ContentView.swift
//  SimpleRecurringTaskManager
//
//  Created by Tom Molinaro on 8/16/26.
//

import SwiftUI
import SwiftData

// Placeholder app shell — Phase 2 replaces this with the themed tab bar
// (Tasks | Past Done | Settings).
struct ContentView: View {
    var body: some View {
        Text("Simple Recurring Task Manager")
            .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Car.self,
            MileageEntry.self,
            Category.self,
            TaskItem.self,
            TaskDoneItem.self,
            SnoozeOption.self,
            AppSettings.self,
        ], inMemory: true)
}
