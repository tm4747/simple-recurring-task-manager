//
//  SharedModelContainer.swift
//  SimpleRecurringTaskManager
//
//  The store lives in the App Group container (not the app's own sandbox) so the
//  widget extension — a separate process — can open the same SwiftData store
//  read/write. Duplicated verbatim into the widget target (see
//  SimpleRecurringTaskManagerWidget/Shared/) rather than shared via a single
//  cross-target file reference, same reasoning as the duplicated @Model files
//  next to it.
//

import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupID = "group.Tom.SimpleRecurringTaskManager"

    static let schema = Schema([
        Car.self,
        MileageEntry.self,
        Category.self,
        TaskItem.self,
        TaskDoneItem.self,
        SnoozeOption.self,
        AppSettings.self,
    ])

    /// Launched by the UI test target with `-UI-TESTING` so every test run starts
    /// from a clean, deterministic, empty store instead of whatever real data
    /// happens to already be in the shared App Group container.
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("UI-TESTING")

    static func make() -> ModelContainer {
        let configuration: ModelConfiguration
        if isUITesting {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                fatalError("Could not resolve App Group container for \(appGroupID)")
            }
            let storeURL = groupURL.appending(path: "SimpleRecurringTaskManager.sqlite")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        }
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }
}
