//
//  DailyPromptsTests.swift
//  MemoryJournalTests
//
//  The daily prompt rotation (Phase 4): stable within a day, fresh each day,
//  5 distinct, guarded for short/empty lists. Uses a fixed UTC calendar so the
//  results don't depend on the test machine's time zone.
//

import Testing
import Foundation
@testable import MemoryJournal

struct DailyPromptsTests {

    private func utc() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test func stableAcrossTimesOnTheSameDay() {
        let cal = utc()
        let morning = DailyPrompts.selection(for: date(2026, 6, 6, hour: 8, cal: cal), calendar: cal)
        let night = DailyPrompts.selection(for: date(2026, 6, 6, hour: 23, cal: cal), calendar: cal)
        #expect(morning == night)
    }

    @Test func changesOnTheNextDay() {
        let cal = utc()
        let day1 = DailyPrompts.selection(for: date(2026, 6, 6, cal: cal), calendar: cal)
        let day2 = DailyPrompts.selection(for: date(2026, 6, 7, cal: cal), calendar: cal)
        #expect(day1 != day2)
    }

    @Test func returnsFiveDistinctPrompts() {
        let cal = utc()
        let picks = DailyPrompts.selection(for: date(2026, 6, 6, cal: cal), calendar: cal)
        #expect(picks.count == 5)
        #expect(Set(picks).count == 5)   // no repeats within a day
    }

    @Test func guardsListShorterThanCount() {
        let cal = utc()
        let picks = DailyPrompts.selection(for: date(2026, 6, 6, cal: cal), from: ["a", "b"], count: 5, calendar: cal)
        #expect(picks.count == 2)
    }

    @Test func emptyListReturnsEmpty() {
        let cal = utc()
        #expect(DailyPrompts.selection(for: date(2026, 6, 6, cal: cal), from: [], calendar: cal).isEmpty)
    }
}
