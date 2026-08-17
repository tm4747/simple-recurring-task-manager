//
//  MileageEngineTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
@testable import SimpleRecurringTaskManager

struct MileageEngineTests {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    @Test func monthlyAverageFallsBackToInitialEstimateWithFewerThanTwoEntries() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 800)
        #expect(MileageEngine.monthlyAverage(for: car) == 800)

        car.mileageEntries = [MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)]
        #expect(MileageEngine.monthlyAverage(for: car) == 800)
    }

    @Test func monthlyAverageComputesFromEarliestAndLatestEntry() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 500)
        car.mileageEntries = [
            MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true),
            MileageEntry(car: car, mileage: 11000, recordedAt: date(2026, 3, 1), isUserEntered: true),
        ]
        // ~2 months apart, 1000 miles added -> roughly 500/month.
        let average = MileageEngine.monthlyAverage(for: car)
        #expect(average > 450 && average < 550)
    }

    @Test func monthlyAverageIgnoresMiddleEntriesUsingOnlyEndpoints() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 0)
        car.mileageEntries = [
            MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true),
            MileageEntry(car: car, mileage: 999_999, recordedAt: date(2026, 2, 1), isUserEntered: false), // wild outlier
            MileageEntry(car: car, mileage: 11000, recordedAt: date(2026, 3, 1), isUserEntered: true),
        ]
        let average = MileageEngine.monthlyAverage(for: car)
        #expect(average > 450 && average < 550)
    }

    @Test func estimatedCurrentMileageFallsBackToInitialMileageWithNoEntries() {
        let car = Car(name: "Civic", initialMileage: 5000)
        #expect(MileageEngine.estimatedCurrentMileage(for: car) == 5000)
    }

    @Test func estimatedCurrentMileageProjectsForwardFromLastEntry() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 1000)
        car.mileageEntries = [MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)]
        let asOf = date(2026, 3, 1) // ~2 months later
        let estimate = MileageEngine.estimatedCurrentMileage(for: car, asOf: asOf)
        #expect(estimate != nil)
        if let estimate {
            // 10000 + ~2 * 1000 ≈ 12000, allow slack for the 30.44-day month approximation.
            #expect(estimate > 11500 && estimate < 12500)
        }
    }

    @Test func recalculatedNextDueUsesMileageTriggerWhenOnlyMileageSet() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 1000)
        car.mileageEntries = [MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)]
        let task = TaskItem(title: "Oil change", car: car, recurrenceType: .byMileage, firstOccurrence: date(2026, 1, 1))
        task.mileageTrigger = 5000
        car.tasks = [task]

        let next = MileageEngine.recalculatedNextDue(for: task, car: car, asOf: date(2026, 1, 1))
        // Needs 5000 more miles at 1000/month -> ~5 months out.
        #expect(next != nil)
        if let next {
            let months = MileageEngine.monthsBetween(date(2026, 1, 1), next)
            #expect(months > 4.5 && months < 5.5)
        }
    }

    @Test func recalculatedNextDueUsesTimeTriggerWhenOnlyTimeSet() {
        let car = Car(name: "Civic")
        let task = TaskItem(title: "Inspection", car: car, recurrenceType: .byMileage, firstOccurrence: date(2026, 1, 1))
        task.timeTriggerMonths = 12
        let next = MileageEngine.recalculatedNextDue(for: task, car: car)
        #expect(next == date(2027, 1, 1))
    }

    @Test func recalculatedNextDuePicksWhicheverTriggerComesFirst() {
        let car = Car(name: "Civic", monthlyMileageEstimate: 2000)
        car.mileageEntries = [MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)]
        let task = TaskItem(title: "Oil change", car: car, recurrenceType: .byMileage, firstOccurrence: date(2026, 1, 1))
        task.mileageTrigger = 2000 // ~1 month out at 2000/month
        task.timeTriggerMonths = 12 // 1 year out
        let next = MileageEngine.recalculatedNextDue(for: task, car: car, asOf: date(2026, 1, 1))
        #expect(next != nil)
        if let next {
            // Mileage trigger (~1 month) should win over the 12-month time trigger.
            #expect(next < date(2026, 6, 1))
        }
    }

    @Test func isPromptDueEveryMonthForFirstThreeMonths() {
        let car = Car(name: "Civic")
        car.createdAt = date(2026, 1, 1)
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 1, 15)))
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 2, 15)))
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 3, 15)))
    }

    @Test func isPromptDueBimonthlyForMonthsFourThroughNine() {
        let car = Car(name: "Civic")
        car.createdAt = date(2026, 1, 1)
        // Month 4 (April) is scheduled; month 5 (May) is not.
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 4, 15)))
        #expect(!MileageEngine.isPromptDue(for: car, asOf: date(2026, 5, 15)))
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 6, 15)))
    }

    @Test func isPromptDueQuarterlyFromMonthTenOn() {
        let car = Car(name: "Civic")
        car.createdAt = date(2026, 1, 1)
        // Month 10 (October) is scheduled; month 11 is not; month 13 (13 months
        // later, i.e. next January) is.
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2026, 10, 15)))
        #expect(!MileageEngine.isPromptDue(for: car, asOf: date(2026, 11, 15)))
        #expect(MileageEngine.isPromptDue(for: car, asOf: date(2027, 1, 15)))
    }

    @Test func isPromptDueFalseIfAlreadyAnsweredThisMonth() {
        let car = Car(name: "Civic")
        car.createdAt = date(2026, 1, 1)
        car.mileageEntries = [MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 10), isUserEntered: true)]
        #expect(!MileageEngine.isPromptDue(for: car, asOf: date(2026, 1, 20)))
    }

    @Test func backfillEstimatedEntriesInterpolatesSkippedMonths() {
        let car = Car(name: "Civic")
        let previous = MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)
        let newEntry = MileageEntry(car: car, mileage: 13000, recordedAt: date(2026, 4, 1), isUserEntered: true)
        car.mileageEntries = [previous, newEntry]

        MileageEngine.backfillEstimatedEntries(for: car, through: newEntry, context: makeInMemoryContext())

        // 3 months apart -> 2 backfilled months (February, March), each not marked
        // user-entered, roughly interpolated between 10000 and 13000.
        let backfilled = car.mileageEntries.filter { !$0.isUserEntered }
        #expect(backfilled.count == 2)
        for entry in backfilled {
            #expect(entry.mileage > 10000 && entry.mileage < 13000)
        }
    }

    @Test func backfillEstimatedEntriesDoesNothingForAdjacentMonths() {
        let car = Car(name: "Civic")
        let previous = MileageEntry(car: car, mileage: 10000, recordedAt: date(2026, 1, 1), isUserEntered: true)
        let newEntry = MileageEntry(car: car, mileage: 10500, recordedAt: date(2026, 2, 1), isUserEntered: true)
        car.mileageEntries = [previous, newEntry]

        MileageEngine.backfillEstimatedEntries(for: car, through: newEntry, context: makeInMemoryContext())

        #expect(car.mileageEntries.count == 2)
    }
}
