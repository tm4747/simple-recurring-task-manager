//
//  DurationStepsTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
@testable import SimpleRecurringTaskManager

struct DurationStepsTests {
    @Test func stepsUpToTheNextListedValue() {
        #expect(DurationSteps.step(from: 300, direction: 1) == 600)
    }

    @Test func stepsDownToThePreviousListedValue() {
        #expect(DurationSteps.step(from: 300, direction: -1) == 240)
    }

    @Test func snapsToNearestValueWhenStartingOffList() {
        // 310 isn't a listed value; nearest is 300, stepping up from there lands on 600.
        #expect(DurationSteps.step(from: 310, direction: 1) == 600)
    }

    @Test func clampsAtTheTopOfTheList() {
        let max = DurationSteps.values.last!
        #expect(DurationSteps.step(from: max, direction: 1) == max)
    }

    @Test func clampsAtTheBottomOfTheList() {
        let min = DurationSteps.values.first!
        #expect(DurationSteps.step(from: min, direction: -1) == min)
    }

    @Test func skipsExcludedValuesWhenSteppingUp() {
        // From 300, stepping up would normally land on 600 — excluding it should
        // skip to the next candidate instead.
        let next = DurationSteps.step(from: 300, direction: 1, excluding: [600])
        #expect(next != 600)
        #expect(next == 900)
    }

    @Test func holdsAtNearestNonExcludedValueWhenEverythingAheadIsExcluded() {
        let allButFirst = Set(DurationSteps.values.dropFirst())
        let result = DurationSteps.step(from: DurationSteps.values.first!, direction: 1, excluding: allButFirst)
        #expect(result == DurationSteps.values.first!)
    }
}
