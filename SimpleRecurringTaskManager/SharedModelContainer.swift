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

    static func make() -> ModelContainer {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            fatalError("Could not resolve App Group container for \(appGroupID)")
        }
        let storeURL = groupURL.appending(path: "SimpleRecurringTaskManager.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create shared ModelContainer: \(error)")
        }
    }
}
