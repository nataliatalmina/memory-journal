//
//  DateLookup.swift
//  MemoryJournal
//
//  The app's most important piece of logic: given a target date, a mode
//  (years or months) and a count N, find the entries that fall on the matching
//  date going back N steps, most recent first.
//
//  Design note: the tricky date arithmetic (which dates to look for, plus the
//  leap-day / short-month rules) is kept in PURE functions that take a
//  `Calendar` and return `[Date]`. They touch no database, so they're trivial
//  to unit-test. The database fetch is a thin layer on top.
//

import Foundation
import SwiftData

struct DateLookup {
    /// Look back across the same month+day over years, or the same day-of-month
    /// over months.
    enum Mode: String, CaseIterable, Identifiable {
        case years
        case months
        var id: String { rawValue }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  >>> THE LEAP-DAY / SHORT-MONTH RULE LIVES HERE. Change `defaultRule`
    //      below (or pass a different rule) if you disagree with the behaviour. <<<
    //
    //  Both edge cases are really the SAME situation — "the target day-of-month
    //  doesn't exist in this step's month":
    //     • 29 Feb in a non-leap year  (leap-day case)
    //     • the 31st in a 30-day month (short-month case)
    // ─────────────────────────────────────────────────────────────────────────
    enum OutOfRangeDayRule {
        /// Fall back to the last valid day of that month (29 Feb → 28 Feb; 31 → 30).
        case clampToLastDayOfMonth
        /// Drop that step entirely — no result for that year/month.
        case skip
    }

    /// The default applied throughout the app. Flip this one line to change the
    /// behaviour everywhere.
    static let defaultRule: OutOfRangeDayRule = .clampToLastDayOfMonth

    var calendar: Calendar
    var outOfRangeRule: OutOfRangeDayRule

    init(calendar: Calendar = .current, outOfRangeRule: OutOfRangeDayRule = DateLookup.defaultRule) {
        self.calendar = calendar
        self.outOfRangeRule = outOfRangeRule
    }

    // MARK: - Pure date math (no database — unit-tested directly)

    /// The list of normalised start-of-day dates to look for, **most recent
    /// first** (index 0 is the target's own date, then one step back, …).
    ///
    /// - years mode:  same month+day, this year and the previous N−1 years.
    /// - months mode: same day-of-month, this month and the previous N−1 months.
    func targetDates(matching targetDate: Date, mode: Mode, count: Int) -> [Date] {
        guard count > 0 else { return [] }

        let base = calendar.startOfDay(for: targetDate)
        let parts = calendar.dateComponents([.year, .month, .day], from: base)
        guard let baseYear = parts.year,
              let baseMonth = parts.month,
              let baseDay = parts.day else { return [] }

        var results: [Date] = []
        for step in 0..<count {
            let stepDate: Date?
            switch mode {
            case .years:
                // Same month & day, walking the year backwards.
                stepDate = resolvedDate(year: baseYear - step, month: baseMonth, day: baseDay)
            case .months:
                stepDate = monthModeDate(stepsBack: step, baseYear: baseYear, baseMonth: baseMonth, day: baseDay)
            }
            if let stepDate { results.append(stepDate) }
        }
        return results
    }

    /// Month-mode helper: the date `stepsBack` whole months before the base month,
    /// keeping the same day-of-month (subject to the out-of-range rule).
    private func monthModeDate(stepsBack: Int, baseYear: Int, baseMonth: Int, day: Int) -> Date? {
        // Subtracting months from the *first of the month* lets Calendar handle
        // year roll-over for us (e.g. one month before January is December of the
        // previous year). We only use this to find the year+month; the day comes
        // from `resolvedDate`.
        guard let firstOfBase = calendar.date(from: DateComponents(year: baseYear, month: baseMonth, day: 1)),
              let monthDate = calendar.date(byAdding: .month, value: -stepsBack, to: firstOfBase) else { return nil }
        let mc = calendar.dateComponents([.year, .month], from: monthDate)
        guard let year = mc.year, let month = mc.month else { return nil }
        return resolvedDate(year: year, month: month, day: day)
    }

    /// Build the normalised start-of-day `Date` for (year, month, desiredDay),
    /// applying `outOfRangeRule` when `desiredDay` doesn't exist in that month.
    /// Returns `nil` when the rule says to skip the step (or on an impossible date).
    private func resolvedDate(year: Int, month: Int, day desiredDay: Int) -> Date? {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return nil }
        let daysInMonth = dayRange.count   // 28, 29, 30, or 31

        let day: Int
        if desiredDay <= daysInMonth {
            day = desiredDay
        } else {
            switch outOfRangeRule {
            case .clampToLastDayOfMonth: day = daysInMonth
            case .skip:                  return nil
            }
        }

        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        return calendar.startOfDay(for: date)
    }

    // MARK: - Database query

    /// Fetch the entries that fall on the target dates, **most recent first**.
    /// Gaps are fine — only the dates that actually have entries come back.
    func matchingEntries(matching targetDate: Date, mode: Mode, count: Int, in context: ModelContext) throws -> [Entry] {
        let targets = targetDates(matching: targetDate, mode: mode, count: count)
        guard let earliest = targets.min(), let latest = targets.max() else { return [] }

        // Two-step fetch on purpose:
        //  1. A `#Predicate` the database CAN run efficiently — narrow to the date
        //     range [earliest, latest] and let the store sort newest-first.
        //     (`#Predicate` can't call Calendar maths, so it can't pick out exact
        //     same-day matches by itself — hence step 2.)
        let predicate = #Predicate<Entry> { $0.date >= earliest && $0.date <= latest }
        let descriptor = FetchDescriptor<Entry>(predicate: predicate,
                                                 sortBy: [SortDescriptor(\.date, order: .reverse)])
        let candidates = try context.fetch(descriptor)

        //  2. Keep only the ones whose normalised day exactly equals a target step.
        //     Both sides were normalised with the same calendar, so `==` is exact.
        let targetSet = Set(targets)
        return candidates.filter { targetSet.contains($0.date) }
    }
}
