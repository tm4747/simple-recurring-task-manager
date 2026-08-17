//
//  DefaultDataSeederTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
import SwiftData
@testable import SimpleRecurringTaskManager

struct DefaultDataSeederTests {
    @Test func seedsCarMaintenanceCategoryAsSystemAndNonDeletable() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedCarMaintenanceCategoryIfNeeded(context: context)

        let categories = try! context.fetch(FetchDescriptor<SimpleRecurringTaskManager.Category>())
        #expect(categories.count == 1)
        #expect(categories.first?.name == DefaultDataSeeder.carMaintenanceCategoryName)
        #expect(categories.first?.isSystem == true)
    }

    @Test func seedingCarMaintenanceCategoryTwiceDoesNotDuplicate() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedCarMaintenanceCategoryIfNeeded(context: context)
        DefaultDataSeeder.seedCarMaintenanceCategoryIfNeeded(context: context)

        let count = try! context.fetchCount(FetchDescriptor<SimpleRecurringTaskManager.Category>())
        #expect(count == 1)
    }

    @Test func seedsFourDefaultSnoozeOptionsInOrder() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedDefaultSnoozeOptionsIfNeeded(context: context)

        let options = try! context.fetch(FetchDescriptor<SnoozeOption>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(options.count == 4)
        #expect(options.map(\.durationSeconds) == [300, 1800, 3600, 10800])
    }

    @Test func seedingSnoozeOptionsTwiceDoesNotDuplicate() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedDefaultSnoozeOptionsIfNeeded(context: context)
        DefaultDataSeeder.seedDefaultSnoozeOptionsIfNeeded(context: context)

        let count = try! context.fetchCount(FetchDescriptor<SnoozeOption>())
        #expect(count == 4)
    }

    @Test func seedsExactlyOneAppSettingsRecord() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedAppSettingsIfNeeded(context: context)
        DefaultDataSeeder.seedAppSettingsIfNeeded(context: context)

        let count = try! context.fetchCount(FetchDescriptor<AppSettings>())
        #expect(count == 1)
    }

    @Test func seedAllIfNeededPopulatesEverything() {
        let context = makeInMemoryContext()
        DefaultDataSeeder.seedAllIfNeeded(context: context)

        #expect(try! context.fetchCount(FetchDescriptor<SimpleRecurringTaskManager.Category>()) == 1)
        #expect(try! context.fetchCount(FetchDescriptor<SnoozeOption>()) == 4)
        #expect(try! context.fetchCount(FetchDescriptor<AppSettings>()) == 1)
    }
}
