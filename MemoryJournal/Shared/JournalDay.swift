//
//  JournalDay.swift
//  MemoryJournal
//
//  HOW A JOURNAL ENTRY'S DATE IS STORED. Read this before touching any date code.
//
//  An entry belongs to a *calendar day* ("15 august 2026"), not to a moment in
//  time. But `Date` isn't a day — it's an exact instant. So we have to choose how
//  to encode a day as an instant, and that choice is the whole ballgame:
//
//    • ORIGINAL approach: midnight of that day in the user's LOCAL time zone.
//      This breaks the moment the user travels. An entry written on 20 July in
//      Athens is stored as 19 July 21:00 UTC; back home in London the app asks
//      "is there an entry at 19 July 23:00 UTC?" and the answer is no. The entry
//      is still in the database but no query can reach it — it looks deleted.
//
//    • CURRENT approach: midnight of that day in UTC, always. The stored instant
//      no longer depends on where the user was standing, so it can't drift.
//
//  The key subtlety: the LOCAL calendar still decides *which* day an entry
//  belongs to — the wall-clock day the user actually lived, which is the whole
//  point of a journal. UTC only decides how that day is *encoded*. Those are two
//  separate steps and collapsing them is a bug: writing at 23:40 in New York is
//  already tomorrow in UTC, so `Calendar.journal.startOfDay(for: .now)` would
//  file it on the wrong day. Always read the components locally, then rebuild
//  them in UTC — which is exactly what `journalDay(in:)` below does.
//
//  RULE: never use `Calendar.current` to build, compare, or format an entry's
//  date. Use `Calendar.journal`, `Date.journalToday`, or `journalDay(in:)`.
//  `Calendar.current` remains correct for "what day is it right now?" questions
//  (see `DailyPrompts`), because that genuinely is a local question.
//
//  GOING THE OTHER WAY. Entry dates are UTC-encoded, but anything we match them
//  against OUTSIDE our own database — photo capture times, files, other apps'
//  data — is not. Those things carry real instants in real time zones, so before
//  comparing, a canonical day has to be *decoded* back into a wall-clock day and
//  rebuilt as a range of instants in the LOCAL calendar. That's
//  `localDayBounds(in:)` below, and it's the exact mirror of `journalDay(in:)`.
//
//  Using the UTC day directly as a range is a real bug, not a rounding error: in
//  Los Angeles, "31 Aug 2025 UTC" spans 5pm on the 30th to 5pm on the 31st, so a
//  photo taken that evening is missed and one from the previous evening is
//  wrongly counted. Same shape as the travel bug, just pointing outwards.
//

import Foundation

extension Calendar {
    /// The calendar used for every *entry date* operation: the user's own
    /// calendar (so locale details like the grid's first weekday still adapt),
    /// but pinned to UTC so day identity never depends on where the user is.
    ///
    /// Computed rather than stored because `Calendar.current` reflects live user
    /// settings — the locale or first-weekday preference can change while the app
    /// is running.
    static var journal: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = .gmt
        return calendar
    }
}

extension Date {
    /// Today's entry date: the wall-clock day the user is living right now,
    /// encoded canonically. Flips at *local* midnight, as it should.
    static var journalToday: Date { Date.now.journalDay() }

    /// The canonical entry date for the day this instant falls on.
    ///
    /// `local` is the calendar that decides which wall-clock day that is — the
    /// user's own by default. Tests pass a fixed calendar to simulate travel.
    func journalDay(in local: Calendar = .current) -> Date {
        let parts = local.dateComponents([.year, .month, .day], from: self)
        let canonical = DateComponents(year: parts.year, month: parts.month, day: parts.day)
        // The fallback can't realistically be hit (the components come straight
        // from a valid date), but `date(from:)` is optional so we handle it.
        return Calendar.journal.date(from: canonical) ?? Calendar.journal.startOfDay(for: self)
    }

    /// True when this instant is already a canonical entry date (UTC midnight).
    /// Used by the one-time migration to tell converted entries from legacy ones.
    var isCanonicalJournalDay: Bool {
        self == Calendar.journal.startOfDay(for: self)
    }

    /// The span of real instants that this canonical journal day covers in a
    /// **local** calendar — the mirror of `journalDay(in:)` (see the file header).
    ///
    /// Use this whenever a journal day has to be compared against timestamps that
    /// came from outside our database (photo capture dates, file dates). Never use
    /// the canonical instant itself as the start of such a range: west of UTC it
    /// starts the range on the previous afternoon.
    ///
    /// The result is a **half-open** `Range` — `start..<end`, i.e. the whole of
    /// that day up to but NOT including the next day's first moment. Returning a
    /// `Range` rather than two loose dates means `contains(_:)` gets the boundary
    /// right for us: 23:59:59 is in, the next midnight is out.
    ///
    /// `local` is the calendar deciding what that day means on the ground — the
    /// user's own by default. Tests pass a fixed calendar to simulate travel.
    func localDayBounds(in local: Calendar = .current) -> Range<Date>? {
        // Decode: which wall-clock day does this canonical instant stand for?
        let parts = Calendar.journal.dateComponents([.year, .month, .day], from: self)

        // Rebuild that day in the local calendar, anchored at NOON rather than
        // midnight. Some days have no midnight — when clocks jump forward at
        // 00:00 the day starts at 01:00 — and noon exists everywhere, so this
        // avoids asking for an instant that doesn't exist. `startOfDay` then
        // gives us the day's true first moment, whatever time that turns out to be.
        guard let noon = local.date(from: DateComponents(year: parts.year,
                                                         month: parts.month,
                                                         day: parts.day,
                                                         hour: 12)),
              let nextNoon = local.date(byAdding: .day, value: 1, to: noon) else { return nil }

        let start = local.startOfDay(for: noon)
        let end = local.startOfDay(for: nextNoon)

        // `Range` traps if the bounds are reversed. They can't be in practice
        // (tomorrow always starts after today), but the initialiser is not
        // failable, so guard rather than risk a crash on some exotic calendar.
        guard start < end else { return nil }
        return start..<end
    }
}
