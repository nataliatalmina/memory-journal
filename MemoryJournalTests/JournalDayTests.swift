//
//  JournalDayTests.swift
//  MemoryJournalTests
//
//  Covers the canonical (UTC-midnight) entry-date encoding and the one-time
//  migration that repairs entries written under the old, zone-dependent one.
//
//  The gap these fill: the existing time-zone tests in DateLookupTests all use ONE
//  calendar for both writing and reading, so they can't catch the travel bug —
//  which needs *write with calendar A, read with calendar B*. Every test here
//  deliberately writes and reads in different zones.
//

import Testing
import Foundation
import SwiftData
@testable import MemoryJournal

@MainActor
struct JournalDayTests {

    // MARK: - Helpers

    func calendar(_ timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    /// A canonical journal day, built directly (UTC midnight of that date).
    func canonical(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// The OLD encoding, for building legacy fixtures: local midnight in `zone`.
    func legacyStored(_ year: Int, _ month: Int, _ day: Int, zone: String) -> Date {
        let cal = calendar(zone)
        return cal.startOfDay(for: cal.date(from: DateComponents(year: year, month: month, day: day))!)
    }

    // MARK: - The travel bug itself

    @Test func entryWrittenAbroadIsFoundBackHome() {
        // The reported bug: an entry written in Santorini, looked for from the UK.
        let athens = calendar("Europe/Athens")
        let written = athens.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 21, minute: 30))!
        let entry = Entry(date: written, body: "Sunset over the caldera", calendar: athens)

        // Home in London, the app asks for that same wall-clock day.
        let london = calendar("Europe/London")
        let lookedFor = london.date(from: DateComponents(year: 2026, month: 7, day: 20))!.journalDay(in: london)

        #expect(entry.date == lookedFor)
        #expect(entry.date == canonical(2026, 7, 20))
    }

    @Test func entryWrittenWestIsFoundBackHome() {
        let losAngeles = calendar("America/Los_Angeles")
        let written = losAngeles.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 8))!
        let entry = Entry(date: written, body: "morning", calendar: losAngeles)

        let tokyo = calendar("Asia/Tokyo")
        let lookedFor = tokyo.date(from: DateComponents(year: 2026, month: 7, day: 20))!.journalDay(in: tokyo)

        #expect(entry.date == lookedFor)
    }

    @Test func lookbackFindsAnEntryWrittenInAnotherZone() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, configurations: config)
        let context = ModelContext(container)

        // Written a year ago, while abroad.
        let athens = calendar("Europe/Athens")
        let abroad = athens.date(from: DateComponents(year: 2025, month: 8, day: 15, hour: 22))!
        context.insert(Entry(date: abroad, body: "last year, away", calendar: athens))
        try context.save()

        // Looked for from home, via the real query path.
        let matches = try DateLookup()
            .matchingEntries(matching: canonical(2026, 8, 15), mode: .years, count: 5, in: context)

        #expect(matches.count == 1)
        #expect(matches.first?.date == canonical(2025, 8, 15))
    }

    // MARK: - Trap 1: the local calendar must pick the day, UTC only encodes it

    @Test func lateEveningWriteWestOfUTCKeepsItsOwnDay() {
        // 23:40 in New York is already the next day in UTC. The entry must still
        // belong to the evening the user lived, not to tomorrow.
        let newYork = calendar("America/New_York")
        let written = newYork.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 23, minute: 40))!
        let entry = Entry(date: written, body: "late night", calendar: newYork)

        #expect(entry.date == canonical(2026, 7, 20))
    }

    @Test func earlyMorningWriteEastOfUTCKeepsItsOwnDay() {
        // The mirror case: 00:20 in Tokyo is still the previous day in UTC.
        let tokyo = calendar("Asia/Tokyo")
        let written = tokyo.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 0, minute: 20))!
        let entry = Entry(date: written, body: "early", calendar: tokyo)

        #expect(entry.date == canonical(2026, 7, 20))
    }

    @Test func differentTimesOnTheSameLocalDayEncodeIdentically() {
        let athens = calendar("Europe/Athens")
        let morning = athens.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 0, minute: 5))!
        let night   = athens.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 23, minute: 55))!

        #expect(Entry(date: morning, body: "a", calendar: athens).date
                == Entry(date: night, body: "b", calendar: athens).date)
    }

    // MARK: - Trap 2: display must not drift either

    @Test func headingRendersTheStoredDayWestOfUTC() {
        // A UTC-midnight instant formatted in a device zone west of UTC renders a
        // day early. This test builds both formatters explicitly so it proves the
        // trap is real rather than passing by luck on a UK machine.
        let stored = canonical(2026, 7, 20)

        func heading(timeZone: TimeZone) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
            return formatter.string(from: stored)
        }

        #expect(heading(timeZone: .gmt) == "20 July 2026")
        // The bug this guards against: left on the device zone, it's a day early.
        #expect(heading(timeZone: TimeZone(identifier: "America/Los_Angeles")!) == "19 July 2026")

        // The app's own heading must use the UTC-pinned one. `journalHeading()` is
        // locale-formatted and lowercased, so compare against the day component the
        // journal calendar reports rather than a hardcoded string.
        let dayNumber = Calendar.journal.component(.day, from: stored)
        #expect(stored.journalHeading().contains("\(dayNumber)"))
        #expect(!stored.journalHeading().contains("19"))
    }

    // MARK: - Canonical-day invariants

    @Test func encodingIsIdempotentForCanonicalDates() {
        let day = canonical(2026, 7, 20)
        #expect(day.journalDay(in: .journal) == day)
        #expect(day.isCanonicalJournalDay)
    }

    @Test func journalCalendarKeepsTheLocalesFirstWeekday() {
        // `.journal` overrides only the time zone — locale-driven grid behaviour
        // (which the Calendar screen relies on) must survive.
        #expect(Calendar.journal.firstWeekday == Calendar.current.firstWeekday)
        #expect(Calendar.journal.timeZone.secondsFromGMT() == 0)
    }

    // MARK: - Migration

    /// The recovery table from the plan: write on 20 July 2026 in each zone under
    /// the OLD encoding, then check the migration recovers the right day.
    @Test(arguments: [
        "Asia/Tokyo", "Europe/London", "Europe/Athens", "America/New_York",
        "America/Los_Angeles", "Asia/Kolkata", "Asia/Kathmandu", "Australia/Sydney",
        "UTC", "America/St_Johns", "Asia/Tehran", "Pacific/Honolulu",
    ])
    func migrationRecoversTheWrittenDay(zone: String) {
        let stored = legacyStored(2026, 7, 20, zone: zone)
        let deviceOffset = TimeZone(identifier: "Europe/London")!.secondsFromGMT(for: stored)

        let recovered = EntryDateMigration.recover(stored, deviceOffset: deviceOffset)

        #expect(recovered.date == canonical(2026, 7, 20), "failed for \(zone)")
    }

    @Test func migrationFlagsTheAmbiguousBandInsteadOfSilentlyGuessing() {
        // UTC+12 can't be distinguished from UTC−12; the result must say so.
        let stored = legacyStored(2026, 7, 20, zone: "Pacific/Auckland")
        let recovered = EntryDateMigration.recover(stored, deviceOffset: 0)

        #expect(recovered.wasAmbiguous)
    }

    @Test func migrationLeavesCanonicalDatesAlone() {
        let day = canonical(2026, 7, 20)
        let recovered = EntryDateMigration.recover(day, deviceOffset: 3600)

        #expect(recovered.date == day)
        #expect(!recovered.wasAmbiguous)
    }

    @Test func migrationRepairsAStoreAndIsIdempotent() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, configurations: config)
        let context = ModelContext(container)

        // Two legacy entries — one written at home in the UK, one in Santorini —
        // plus one already-canonical entry. Set `date` directly to bypass the new
        // encoding in `init`, so these really are legacy-shaped rows.
        let athensEntry = Entry(date: .now, body: "Santorini")
        athensEntry.date = legacyStored(2026, 7, 20, zone: "Europe/Athens")
        let londonEntry = Entry(date: .now, body: "home")
        londonEntry.date = legacyStored(2026, 6, 10, zone: "Europe/London")
        let canonicalEntry = Entry(date: .now, body: "already fine")
        canonicalEntry.date = canonical(2026, 5, 1)

        for entry in [athensEntry, londonEntry, canonicalEntry] { context.insert(entry) }
        try context.save()

        let result = EntryDateMigration.migrate(context)

        #expect(athensEntry.date == canonical(2026, 7, 20))
        #expect(londonEntry.date == canonical(2026, 6, 10))
        #expect(canonicalEntry.date == canonical(2026, 5, 1))
        #expect(result.ambiguousCount == 0)

        // Running it again must change nothing.
        let second = EntryDateMigration.migrate(context)
        #expect(second.converted == 0)
        #expect(athensEntry.date == canonical(2026, 7, 20))
    }

    @Test func migratedEntryIsReachableFromTheCalendarScreensLookup() throws {
        // End-to-end: the exact reported symptom. A legacy Santorini entry is
        // invisible to a same-day lookup at home, and visible again after the
        // migration — which is what the Calendar screen does when you tap a day.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, configurations: config)
        let context = ModelContext(container)

        let entry = Entry(date: .now, body: "Sunset over the caldera")
        entry.date = legacyStored(2026, 7, 20, zone: "Europe/Athens")
        context.insert(entry)
        try context.save()

        let tappedDay = canonical(2026, 7, 20)
        let all = { (try? context.fetch(FetchDescriptor<Entry>())) ?? [] }

        #expect(all().first { $0.date == tappedDay } == nil)   // the bug
        EntryDateMigration.migrate(context)
        #expect(all().first { $0.date == tappedDay } != nil)   // repaired
    }
}
