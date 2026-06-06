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
import UIKit

enum SampleData {
    /// Seed only if the store is empty — safe to call on every launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Entry>())) ?? 0
        guard existing == 0 else { return }
        reseed(context)
    }

    /// Wipe everything and seed fresh. Wired to the "Reseed" button in the dev view.
    static func reseed(_ context: ModelContext) {
        writeSampleMedia()                        // real thumbnails for the photo rows
        try? context.delete(model: Entry.self)    // bulk-delete all entries
        for entry in makeEntries() {
            context.insert(entry)
        }
        try? context.save()
    }

    /// Remove every entry — used by the dev tab to preview the empty home state.
    static func clearAll(_ context: ModelContext) {
        try? context.delete(model: Entry.self)
        try? context.save()
    }

    /// Insert an entry dated TODAY (if there isn't one), so we can preview the
    /// "today's entry in the header + Edit memory" state. Matches the Figma copy.
    static func seedTodayEntry(_ context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let all = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        guard !all.contains(where: { $0.date == today }) else { return }
        writeSampleMedia()
        context.insert(Entry(
            date: today,
            title: "Day at the park",
            body: "Today I went to the park. It was so wonderful to just sit and read and feel the sunshine on my skin. Not rushing anywhere. I wish every day was like this.",
            photoFilenames: ["sample-ocean.jpg"]
        ))
        try? context.save()
    }

    /// Seeded entries are built RELATIVE TO TODAY so the home look-back list is
    /// populated whenever you run the app, in BOTH modes:
    ///   • year mode  → same month/day, previous years (with a gap)
    ///   • month mode → same day-of-month, previous months (with a gap)
    /// Each window includes a photo entry, a voice-note entry, and a plain one,
    /// plus titled and untitled examples.
    static func makeEntries() -> [Entry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        func yearsAgo(_ n: Int) -> Date { calendar.date(byAdding: .year, value: -n, to: today) ?? today }
        func monthsAgo(_ n: Int) -> Date { calendar.date(byAdding: .month, value: -n, to: today) ?? today }
        func fixed(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? today
        }

        let longBody = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."

        return [
            // ── YEAR-mode window (same month/day as today). Year −3 missing = gap.
            Entry(date: yearsAgo(1), title: "Quiet morning", body: "Coffee on the balcony, watching the street slowly wake up.", photoFilenames: ["sample-ocean.jpg"]),
            Entry(date: yearsAgo(2), body: longBody),
            Entry(date: yearsAgo(4), body: "A short voice memo from a long walk.", voiceNoteFilename: "sample-voice.m4a"),

            // ── MONTH-mode window (same day-of-month as today). Month −3 missing = gap.
            Entry(date: monthsAgo(1), title: "Concert", body: "Front-row seats — ears still ringing the next day.", photoFilenames: ["sample-sunset.jpg"]),
            Entry(date: monthsAgo(2), body: longBody),
            Entry(date: monthsAgo(4), body: "Recorded the rain on the window.", voiceNoteFilename: "sample-voice.m4a"),

            // ── Edge-case fodder + noise (mainly for the DateLookup dev tab).
            Entry(date: fixed(2024, 2, 29), title: "Leap day", body: "An extra day this year."),
            Entry(date: fixed(2026, 1, 31), title: "End of January", body: "New month tomorrow."),
            Entry(date: fixed(2026, 3, 31), title: "End of March", body: "Spring is here."),
            Entry(date: fixed(2025, 12, 25), title: "Holidays", body: "Family dinner."),
        ]
    }

    /// Generate the gradient stand-in photos the seeded entries point at, so the
    /// home rows show a real thumbnail. (Real photo capture is Part C.)
    private static func writeSampleMedia() {
        MediaStore.writeSampleImage(filename: "sample-ocean.jpg",
                                    top: UIColor(red: 0.30, green: 0.62, blue: 0.66, alpha: 1),
                                    bottom: UIColor(red: 0.00, green: 0.33, blue: 0.39, alpha: 1))
        MediaStore.writeSampleImage(filename: "sample-sunset.jpg",
                                    top: UIColor(red: 0.86, green: 0.62, blue: 0.45, alpha: 1),
                                    bottom: UIColor(red: 0.36, green: 0.56, blue: 0.61, alpha: 1))
    }
}
#endif
