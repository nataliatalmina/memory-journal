//
//  CalendarMonthTests.swift
//  MemoryJournalTests
//
//  The Calendar screen's pure month-grid maths (Phase 5): correct leading blanks,
//  correct day count, correct weekday-header order. Uses fixed calendars so the
//  results don't depend on the test machine's locale or time zone.
//

import Testing
import Foundation
@testable import MemoryJournal

struct CalendarMonthTests {

    /// A Sunday-first calendar (US-style) in UTC with English symbols.
    private func sundayFirst() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.locale = Locale(identifier: "en_US")
        c.firstWeekday = 1
        return c
    }

    /// A Monday-first calendar (much of Europe) in UTC with English symbols.
    private func mondayFirst() -> Calendar {
        var c = sundayFirst()
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Grid shape

    @Test func gridIsAlwaysWholeWeeks() {
        let cal = sundayFirst()
        let month = CalendarMonth(containing: date(2026, 8, 15, cal: cal), calendar: cal)
        #expect(month.gridDays.count % 7 == 0)
    }

    @Test func gridContainsExactlyTheMonthsDays() {
        let cal = sundayFirst()
        let month = CalendarMonth(containing: date(2026, 8, 1, cal: cal), calendar: cal)
        let realDays = month.gridDays.compactMap { $0 }
        #expect(realDays.count == 31)            // August has 31 days
        #expect(month.numberOfDays == 31)
        // Days are consecutive and in order, starting at the 1st.
        #expect(realDays.first == month.firstDay)
        for (offset, day) in realDays.enumerated() {
            #expect(cal.component(.day, from: day) == offset + 1)
        }
    }

    // MARK: - Leading blanks line the 1st up under the right weekday

    @Test func august2026StartsOnSaturdayColumn_sundayFirst() {
        // 1 August 2026 is a Saturday → with a Sunday-first grid the 1st sits in the
        // 7th column, i.e. 6 leading blanks.
        let cal = sundayFirst()
        let month = CalendarMonth(containing: date(2026, 8, 1, cal: cal), calendar: cal)
        let leadingBlanks = month.gridDays.prefix { $0 == nil }.count
        #expect(leadingBlanks == 6)
        #expect(month.gridDays[6] == month.firstDay)
    }

    @Test func augustMondayFirstShiftsTheBlanks() {
        // Same month, Monday-first: Saturday is the 6th column → 5 leading blanks.
        let cal = mondayFirst()
        let month = CalendarMonth(containing: date(2026, 8, 1, cal: cal), calendar: cal)
        let leadingBlanks = month.gridDays.prefix { $0 == nil }.count
        #expect(leadingBlanks == 5)
    }

    // MARK: - Leap February

    @Test func leapFebruaryHas29Days() {
        let cal = sundayFirst()
        let month = CalendarMonth(containing: date(2024, 2, 10, cal: cal), calendar: cal)
        #expect(month.numberOfDays == 29)
        #expect(month.gridDays.compactMap { $0 }.count == 29)
        // 1 Feb 2024 is a Thursday → 4 leading blanks in a Sunday-first grid.
        let leadingBlanks = month.gridDays.prefix { $0 == nil }.count
        #expect(leadingBlanks == 4)
    }

    // MARK: - Weekday header order

    @Test func weekdayHeaderFollowsFirstWeekday() {
        #expect(CalendarMonth(containing: .now, calendar: sundayFirst()).weekdaySymbols.first == "SUN")
        #expect(CalendarMonth(containing: .now, calendar: mondayFirst()).weekdaySymbols.first == "MON")
        // Seven distinct labels — the bug the mockup had (duplicate SUN, missing TUE).
        let symbols = CalendarMonth(containing: .now, calendar: sundayFirst()).weekdaySymbols
        #expect(symbols.count == 7)
        #expect(Set(symbols).count == 7)
    }

    // MARK: - Month stepping

    @Test func previousAndNextStepWholeMonths() {
        let cal = sundayFirst()
        let august = CalendarMonth(containing: date(2026, 8, 15, cal: cal), calendar: cal)
        #expect(august.previous().firstDay == date(2026, 7, 1, cal: cal))
        #expect(august.next().firstDay == date(2026, 9, 1, cal: cal))
        // Year roll-over.
        let january = CalendarMonth(containing: date(2026, 1, 10, cal: cal), calendar: cal)
        #expect(january.previous().firstDay == date(2025, 12, 1, cal: cal))
    }
}
