//
//  AppSettingsTests.swift
//  SimpleRecurringTaskManagerTests
//

import Testing
import Foundation
import SwiftData
@testable import SimpleRecurringTaskManager

struct AppSettingsTests {
    @Test func timeHelperProducesTheRequestedHourAndMinute() {
        let result = AppSettings.time(hour: 18, minute: 30)
        let components = Calendar.current.dateComponents([.hour, .minute], from: result)
        #expect(components.hour == 18)
        #expect(components.minute == 30)
    }

    @Test func nextWeekdayFindsTheSameDayWhenReferenceIsAlreadyThatWeekday() {
        // 2026-08-15 is a Saturday.
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 15
        let saturday = Calendar.current.date(from: components)!

        let result = AppSettings.nextWeekday(.saturday, hour: 9, minute: 0, from: saturday)
        #expect(Calendar.current.isDate(result, inSameDayAs: saturday))
    }

    @Test func nextWeekdayFindsTheUpcomingOccurrenceWhenReferenceIsNotThatWeekday() {
        // 2026-08-17 is a Monday; the next Saturday is 2026-08-22.
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 17
        let monday = Calendar.current.date(from: components)!

        let result = AppSettings.nextWeekday(.saturday, hour: 9, minute: 0, from: monday)
        let resultComponents = Calendar.current.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.day == 22)
        #expect(Calendar.current.component(.weekday, from: result) == 7) // Saturday
    }

    @Test func themeGetterFallsBackToLightForUnknownRawValue() {
        let settings = AppSettings()
        settings.selectedTheme = "not-a-real-theme"
        #expect(settings.theme == .light)
    }

    @Test func themeSetterRoundTripsThroughRawValue() {
        let settings = AppSettings()
        settings.theme = .retro
        #expect(settings.selectedTheme == "retro")
        #expect(settings.theme == .retro)
    }

    @Test func sharedCreatesExactlyOneRecordAndReusesItOnSubsequentCalls() {
        let context = makeInMemoryContext()
        let first = AppSettings.shared(in: context)
        let second = AppSettings.shared(in: context)
        #expect(first.id == second.id)

        let count = try! context.fetchCount(FetchDescriptor<AppSettings>())
        #expect(count == 1)
    }
}
