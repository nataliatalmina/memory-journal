//
//  CalendarMonth.swift
//  MemoryJournal
//
//  Pure month-grid maths for the Calendar screen: "given a month, lay it out as a
//  grid of weeks". No SwiftUI, no database — just `Calendar`/`DateComponents` work
//  — so it's trivial to unit-test with a fixed calendar (mirrors how
//  `Services/DateLookup.swift` keeps its date arithmetic separate from the UI).
//
//  Time zone: we use the caller's `Calendar` (the app passes `.current`), so the
//  grid, the selected day, and `Entry.date` all share the SAME local calendar and
//  time zone. That's the Phase 1 normalisation rule — every date here is a
//  start-of-day instant in the user's local time zone — so comparing a tapped grid
//  day against a stored entry's date is exact.
//

import Foundation

struct CalendarMonth {
    /// The calendar to lay out in. It carries the locale's *first weekday* (Sunday
    /// in the US, Monday in much of Europe) and the time zone, so the grid adapts
    /// automatically rather than us hardcoding "weeks start on Sunday".
    let calendar: Calendar

    /// The first moment of the displayed month (start-of-day on the 1st).
    let firstDay: Date

    /// Build the month that *contains* the given date (any day in the month works).
    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        // Keep only year+month, drop the day/time → the 1st of that month at 00:00.
        let comps = calendar.dateComponents([.year, .month], from: date)
        self.firstDay = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// How many days the month has (28, 29, 30, or 31).
    var numberOfDays: Int {
        calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 0
    }

    /// The grid cells, row-major, exactly 7 per week:
    ///   • leading `nil`s so day 1 sits under its real weekday column,
    ///   • one start-of-day `Date` per day of the month,
    ///   • trailing `nil`s padding the final week back up to 7.
    /// `nil` means "an empty cell" (a blank before the 1st or after the last day).
    var gridDays: [Date?] {
        // `.weekday` is 1 = Sunday … 7 = Saturday (Gregorian). `firstWeekday` is the
        // locale's leading column (1 = Sunday in the US). The leading-blank count is
        // simply how far the 1st sits to the right of that leading column, mod 7.
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<numberOfDays {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        // Pad the last partial week so every row has 7 cells.
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    /// Weekday header labels in the locale's column order, uppercased to match the
    /// design (e.g. SUN MON TUE WED THU FRI SAT in the US; MON…SUN where Monday is
    /// the first weekday). Derived from `Calendar`, never hardcoded — this is the
    /// fix for the mockup's garbled "SUN MON WED … SUN" header row.
    var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols      // always Sunday-first: Sun…Sat
        let shift = calendar.firstWeekday - 1           // rotate to the locale's start
        let ordered = Array(symbols[shift...] + symbols[..<shift])
        return ordered.map { $0.uppercased() }
    }

    /// "August 2026" for the month header.
    var title: String { firstDay.monthYearHeading() }

    /// The adjacent months (for the prev / next chevrons).
    func previous() -> CalendarMonth {
        let date = calendar.date(byAdding: .month, value: -1, to: firstDay) ?? firstDay
        return CalendarMonth(containing: date, calendar: calendar)
    }

    func next() -> CalendarMonth {
        let date = calendar.date(byAdding: .month, value: 1, to: firstDay) ?? firstDay
        return CalendarMonth(containing: date, calendar: calendar)
    }
}
