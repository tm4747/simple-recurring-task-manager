//
//  TimeFormattingTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
@testable import SimpleRecurringTaskManager

struct TimeFormattingTests {
    @Test func formattedAsTimerUsesMinutesSecondsUnderAnHour() {
        #expect(125.formattedAsTimer == "02:05")
    }

    @Test func formattedAsTimerUsesHoursMinutesSecondsOverAnHour() {
        #expect(3665.formattedAsTimer == "1:01:05")
    }

    @Test func formattedAsDurationOmitsZeroComponents() {
        #expect(0.formattedAsDuration == "0 sec")
        #expect(30.formattedAsDuration == "30 sec")
        #expect(300.formattedAsDuration == "5 min")
        #expect(3600.formattedAsDuration == "1 hr")
        #expect(5400.formattedAsDuration == "1 hr 30 min")
    }
}
