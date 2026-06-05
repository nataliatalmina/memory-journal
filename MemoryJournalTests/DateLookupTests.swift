//
//  DateLookupTests.swift
//  MemoryJournalTests
//
//  Unit tests for the same-date look-back logic, using the Swift Testing
//  framework (`import Testing`, `@Test`, `#expect`).
//
//  The pure tests inject a FIXED calendar so results never depend on the
//  machine's locale or time zone. `@testable import` lets the tests see the
//  app's internal types.
//

import Testing
import Foundation
import SwiftData
@testable import MemoryJournal

@MainActor
struct DateLookupTests {

    // MARK: - Helpers

    /// A fixed Gregorian calendar pinned to a chosen time zone.
    func calendar(_ timeZoneID: String = "UTC") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    /// Build a normalised start-of-day date in the given calendar.
    func day(_ year: Int, _ month: Int, _ d: Int, _ calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: month, day: d))!)
    }

    // MARK: - Basic year / month walking

    @Test func yearModeWalksBackByYear() {
        let cal = calendar()
        let result = DateLookup(calendar: cal)
            .targetDates(matching: day(2026, 8, 15, cal), mode: .years, count: 5)
        #expect(result == [day(2026, 8, 15, cal), day(2025, 8, 15, cal), day(2024, 8, 15, cal),
                           day(2023, 8, 15, cal), day(2022, 8, 15, cal)])
    }

    @Test func monthModeWalksBackByMonth() {
        let cal = calendar()
        let result = DateLookup(calendar: cal)
            .targetDates(matching: day(2026, 8, 15, cal), mode: .months, count: 5)
        #expect(result == [day(2026, 8, 15, cal), day(2026, 7, 15, cal), day(2026, 6, 15, cal),
                           day(2026, 5, 15, cal), day(2026, 4, 15, cal)])
    }

    @Test func monthModeCrossesYearBoundary() {
        let cal = calendar()
        let result = DateLookup(calendar: cal)
            .targetDates(matching: day(2026, 2, 15, cal), mode: .months, count: 4)
        #expect(result == [day(2026, 2, 15, cal), day(2026, 1, 15, cal),
                           day(2025, 12, 15, cal), day(2025, 11, 15, cal)])
    }

    // MARK: - Leap-day rule (29 Feb)

    @Test func leapDayClampsToFeb28InNonLeapYears() {
        let cal = calendar()
        let result = DateLookup(calendar: cal, outOfRangeRule: .clampToLastDayOfMonth)
            .targetDates(matching: day(2024, 2, 29, cal), mode: .years, count: 3)
        // 2024 is a leap year (29 exists); 2023 & 2022 are not → clamp to 28.
        #expect(result == [day(2024, 2, 29, cal), day(2023, 2, 28, cal), day(2022, 2, 28, cal)])
    }

    @Test func leapDaySkipDropsNonLeapYears() {
        let cal = calendar()
        let result = DateLookup(calendar: cal, outOfRangeRule: .skip)
            .targetDates(matching: day(2024, 2, 29, cal), mode: .years, count: 5)
        // Across 2024…2020 only leap years keep 29 Feb: 2024 and 2020.
        #expect(result == [day(2024, 2, 29, cal), day(2020, 2, 29, cal)])
    }

    // MARK: - Short-month rule (the 31st)

    @Test func thirtyFirstClampsInShortMonths() {
        let cal = calendar()
        let result = DateLookup(calendar: cal, outOfRangeRule: .clampToLastDayOfMonth)
            .targetDates(matching: day(2026, 3, 31, cal), mode: .months, count: 4)
        // Mar 31 → Feb 2026 (28 days, non-leap) clamps to 28 → Jan 31 → Dec 31.
        #expect(result == [day(2026, 3, 31, cal), day(2026, 2, 28, cal),
                           day(2026, 1, 31, cal), day(2025, 12, 31, cal)])
    }

    @Test func thirtyFirstSkipsShortMonths() {
        let cal = calendar()
        let result = DateLookup(calendar: cal, outOfRangeRule: .skip)
            .targetDates(matching: day(2026, 1, 31, cal), mode: .months, count: 4)
        // Jan 31 → Dec 31 → Nov has only 30 days (skipped) → Oct 31.
        #expect(result == [day(2026, 1, 31, cal), day(2025, 12, 31, cal), day(2025, 10, 31, cal)])
    }

    // MARK: - Ordering, count, empty

    @Test func resultsAreMostRecentFirst() {
        let cal = calendar()
        let result = DateLookup(calendar: cal)
            .targetDates(matching: day(2026, 8, 15, cal), mode: .years, count: 5)
        #expect(result == result.sorted(by: >))
    }

    @Test func zeroCountReturnsEmpty() {
        let cal = calendar()
        let result = DateLookup(calendar: cal)
            .targetDates(matching: day(2026, 8, 15, cal), mode: .years, count: 0)
        #expect(result.isEmpty)
    }

    // MARK: - Time-zone / DST normalisation

    @Test func differentTimesOnSameLocalDayNormaliseEqually() {
        // 9 March 2025 is the US spring-forward day (02:00 → 03:00 in New York).
        let cal = calendar("America/New_York")
        let justAfterMidnight = cal.date(from: DateComponents(year: 2025, month: 3, day: 9, hour: 0, minute: 30))!
        let lateEvening       = cal.date(from: DateComponents(year: 2025, month: 3, day: 9, hour: 23, minute: 30))!
        // Despite the clocks jumping forward mid-day, both belong to the same
        // local calendar day and must normalise to the same instant.
        #expect(cal.startOfDay(for: justAfterMidnight) == cal.startOfDay(for: lateEvening))
    }

    @Test func entryStoresStartOfDayInGivenCalendar() {
        let cal = calendar("America/New_York")
        let lateNight = cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 22, minute: 45))!
        let entry = Entry(date: lateNight, body: "late night", calendar: cal)
        #expect(entry.date == cal.startOfDay(for: lateNight))
    }

    // MARK: - Integration: the actual database fetch (in-memory store)

    @Test func fetchReturnsMatchesMostRecentFirstAndIgnoresGapsAndNoise() throws {
        // An in-memory SwiftData store — no files, lives only for this test.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, configurations: config)
        let context = ModelContext(container)

        let cal = Calendar.current   // Entry + DateLookup must agree → use the same calendar
        func d(_ y: Int, _ m: Int, _ day: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day))!
        }

        // Aug 15 across years (2023 missing = gap) + unrelated noise.
        for date in [d(2026, 8, 15), d(2025, 8, 15), d(2024, 8, 15), d(2022, 8, 15),
                     d(2026, 8, 3), d(2025, 1, 1)] {
            context.insert(Entry(date: date, body: "x"))
        }
        try context.save()

        let matches = try DateLookup()
            .matchingEntries(matching: d(2026, 8, 15), mode: .years, count: 5, in: context)

        #expect(matches.map(\.date) == [cal.startOfDay(for: d(2026, 8, 15)),
                                        cal.startOfDay(for: d(2025, 8, 15)),
                                        cal.startOfDay(for: d(2024, 8, 15)),
                                        cal.startOfDay(for: d(2022, 8, 15))])
    }
}
