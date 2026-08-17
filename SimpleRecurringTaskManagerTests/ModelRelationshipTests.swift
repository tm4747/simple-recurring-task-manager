//
//  ModelRelationshipTests.swift
//  SimpleRecurringTaskManagerTests
//
//  Verifies the delete-rule choices on each @Model relationship actually behave
//  as documented against a real (in-memory) SwiftData store — transient object
//  graphs in the other test files don't exercise SwiftData's own cascade/nullify
//  machinery, only in-memory-but-persisted ones do.
//

import Testing
import SwiftData
@testable import SimpleRecurringTaskManager

struct ModelRelationshipTests {
    @Test func deletingCategoryReassignsItsTasksToUncategorizedInsteadOfDeletingThem() {
        let context = makeInMemoryContext()
        let category = Category(name: "Chores")
        let task = TaskItem(title: "Vacuum", category: category, recurrenceType: .weekly, firstOccurrence: .now)
        context.insert(category)
        context.insert(task)
        try! context.save()

        context.delete(category)
        try! context.save()

        let tasks = try! context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.category == nil)
    }

    @Test func deletingCarReassignsItsTasksToUncategorizedCar() {
        let context = makeInMemoryContext()
        let car = Car(name: "Civic")
        let task = TaskItem(title: "Oil change", car: car, recurrenceType: .byMileage, firstOccurrence: .now)
        context.insert(car)
        context.insert(task)
        try! context.save()

        context.delete(car)
        try! context.save()

        let tasks = try! context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.car == nil)
    }

    @Test func deletingCarCascadeDeletesItsMileageEntries() {
        let context = makeInMemoryContext()
        let car = Car(name: "Civic")
        let entry = MileageEntry(car: car, mileage: 1000, isUserEntered: true)
        context.insert(car)
        context.insert(entry)
        try! context.save()

        context.delete(car)
        try! context.save()

        let entries = try! context.fetch(FetchDescriptor<MileageEntry>())
        #expect(entries.isEmpty)
    }

    @Test func deletingTaskCascadeDeletesItsDoneItems() {
        let context = makeInMemoryContext()
        let task = TaskItem(title: "Water plants", recurrenceType: .weekly, firstOccurrence: .now)
        let doneItem = TaskDoneItem(task: task, wasDone: true)
        context.insert(task)
        context.insert(doneItem)
        try! context.save()

        context.delete(task)
        try! context.save()

        let doneItems = try! context.fetch(FetchDescriptor<TaskDoneItem>())
        #expect(doneItems.isEmpty)
    }

    @Test func deletingTaskDoesNotDeleteItsCategoryOrCar() {
        let context = makeInMemoryContext()
        let category = Category(name: "Car Maintenance", isSystem: true)
        let car = Car(name: "Civic")
        let task = TaskItem(title: "Oil change", category: category, car: car, recurrenceType: .byMileage, firstOccurrence: .now)
        context.insert(category)
        context.insert(car)
        context.insert(task)
        try! context.save()

        context.delete(task)
        try! context.save()

        #expect(try! context.fetchCount(FetchDescriptor<Category>()) == 1)
        #expect(try! context.fetchCount(FetchDescriptor<Car>()) == 1)
    }
}
