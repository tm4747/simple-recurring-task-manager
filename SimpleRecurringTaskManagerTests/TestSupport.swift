//
//  TestSupport.swift
//  SimpleRecurringTaskManagerTests
//

import Foundation
import SwiftData
@testable import SimpleRecurringTaskManager

/// A fresh in-memory ModelContext, isolated per call — used by any test that
/// needs to actually insert objects (most model-logic tests just build transient
/// object graphs directly and never need this).
func makeInMemoryContext() -> ModelContext {
    let container = try! ModelContainer(for: SharedModelContainer.schema, configurations: [
        ModelConfiguration(schema: SharedModelContainer.schema, isStoredInMemoryOnly: true),
    ])
    return ModelContext(container)
}
