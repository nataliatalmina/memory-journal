//
//  Entry.swift
//  MemoryJournal
//
//  The SwiftData model for a single journal entry.
//

import Foundation
import SwiftData

// `@Model` is the SwiftData macro that turns a plain class into a persistent
// model: behind the scenes it generates the code to store instances of this
// class in the local database and to observe changes to its properties.
//
// A `@Model` must be a `class` (a reference type), not a `struct` — SwiftData
// needs a stable identity it can track across edits. `final` just says "nobody
// subclasses this", which is good practice and slightly faster.
@Model
final class Entry {
    // `@Attribute(.unique)` tells SwiftData this value must be unique across all
    // entries. A fresh `UUID` (a random 128-bit identifier) guarantees that.
    @Attribute(.unique) var id: UUID

    /// The calendar date this entry belongs to, **normalised to start-of-day**
    /// so that same-date matching is exact (every entry written on 15 Aug 2026
    /// stores the *same* instant — midnight that day — regardless of the time it
    /// was actually written). See `init` for how and in which time zone.
    var date: Date

    /// Optional short title, e.g. "Day at the park". `String?` means "a String
    /// or nothing" — the `?` marks it optional.
    var title: String?

    /// The entry text. (Named `body`; that's fine here — this is a data model,
    /// not a SwiftUI `View`, so there's no clash with `View.body`.)
    var body: String

    /// Filenames of photos kept in the app's own container — we store *references*
    /// (filenames), never the raw image bytes, in the database. Real capture is
    /// wired up in a later phase; seeded data uses placeholder names.
    var photoFilenames: [String]

    /// Optional filename of a voice note in the app container.
    var voiceNoteFilename: String?

    /// Optional reference to the prompt that seeded this entry.
    var promptUsed: String?

    var createdAt: Date
    var modifiedAt: Date

    init(date: Date,
         title: String? = nil,
         body: String,
         photoFilenames: [String] = [],
         voiceNoteFilename: String? = nil,
         promptUsed: String? = nil,
         calendar: Calendar = .current,
         createdAt: Date = .now) {
        self.id = UUID()

        // Normalise to the *first moment of the day* in the user's current
        // calendar and time zone (LOCAL, deliberately not UTC): an entry belongs
        // to the wall-clock date the user experienced. `startOfDay(for:)` is
        // DST-safe — it returns the real first instant of the day even on days
        // where that isn't exactly 00:00.
        //
        // The `calendar` parameter exists so seeding and tests can pass a fixed
        // calendar; day-to-day app code just uses the default `.current`.
        self.date = calendar.startOfDay(for: date)

        self.title = title
        self.body = body
        self.photoFilenames = photoFilenames
        self.voiceNoteFilename = voiceNoteFilename
        self.promptUsed = promptUsed
        self.createdAt = createdAt
        self.modifiedAt = createdAt
    }
}
