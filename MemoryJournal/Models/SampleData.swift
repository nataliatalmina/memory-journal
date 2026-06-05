//
//  SampleData.swift
//  MemoryJournal
//
//  Seeded sample entries so we can SEE the query working before any real UI
//  or real data exists. The whole file is wrapped in `#if DEBUG`, so none of
//  it is compiled into a release build.
//

#if DEBUG
import Foundation
import SwiftData

enum SampleData {
    /// Seed only if the store is empty — safe to call on every launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
        guard existing == 0 else { return }
        reseed(context)
    }

    /// Wipe everything and seed fresh. Wired to the "Reseed" button in the dev view.
    static func reseed(_ context: ModelContext) {
        try? context.delete(model: Entry.self)   // bulk-delete all entries
        for entry in makeEntries() {
            context.insert(entry)
        }
        try? context.save()
    }

    /// A deliberate spread so BOTH modes show results AND visible gaps.
    static func makeEntries() -> [Entry] {
        // Tiny helper to build a date from year/month/day in the current calendar.
        func d(_ year: Int, _ month: Int, _ day: Int) -> Date {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
        }

        return [
            // ── Same MONTH+DAY (Aug 15) across years → exercises YEAR mode.
            //    2023 is intentionally missing to show a gap.
            Entry(date: d(2026, 8, 15), title: "Day at the park", body: "Sunny picnic and a long walk.", photoFilenames: ["park-1.jpg", "park-2.jpg"]),
            Entry(date: d(2025, 8, 15), title: "Quiet morning", body: "Coffee on the balcony.", photoFilenames: ["balcony.jpg"]),
            Entry(date: d(2024, 8, 15), title: "Beach trip", body: "Cold water, warm sand.", voiceNoteFilename: "waves.m4a"),
            Entry(date: d(2022, 8, 15), title: "Moving day", body: "Boxes everywhere, but we made it."),

            // ── Same DAY-OF-MONTH (the 15th) across months of 2026 → exercises MONTH mode.
            //    April 15 is intentionally missing to show a gap.
            Entry(date: d(2026, 7, 15), title: "Concert", body: "Front-row seats.", promptUsed: "What made you smile today?"),
            Entry(date: d(2026, 6, 15), title: "Garden", body: "The tomatoes are finally ripening."),
            Entry(date: d(2026, 5, 15), title: "Rainy day", body: "Read all afternoon."),

            // ── Edge-case fodder: a leap day and two month-ends (the 31st).
            //    Target 29 Feb or the 31st in the dev view to watch the rules apply.
            Entry(date: d(2024, 2, 29), title: "Leap day", body: "An extra day this year."),
            Entry(date: d(2026, 1, 31), title: "End of January", body: "New month tomorrow."),
            Entry(date: d(2026, 3, 31), title: "End of March", body: "Spring is here."),

            // ── Unrelated noise, so matching has to actually filter these OUT.
            Entry(date: d(2026, 8, 3),  title: "Random Tuesday", body: "Nothing special."),
            Entry(date: d(2025, 12, 25), title: "Holidays", body: "Family dinner."),
            Entry(date: d(2026, 2, 10), title: "Snow", body: "First snow of the year."),
        ]
    }
}
#endif
