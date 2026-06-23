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

extension Entry {
    /// Normalise raw composer field text for saving:
    ///  - trims leading/trailing whitespace and newlines from both,
    ///  - an all-whitespace title becomes `nil` (title is optional),
    ///  - the body is returned trimmed and may be empty (an entry can be carried
    ///    by media alone — see `hasSavableContent`).
    static func cleanedInput(title: String, body: String) -> (title: String?, body: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedTitle.isEmpty ? nil : trimmedTitle, trimmedBody)
    }

    /// The single source of truth for "is there enough to save?". An entry needs
    /// **any real content** — body text, at least one photo, or a voice note. A
    /// title on its own is NOT enough (it's metadata, not content).
    static func hasSavableContent(body: String, photoCount: Int, hasAudio: Bool) -> Bool {
        let hasBody = !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasBody || photoCount > 0 || hasAudio
    }

    /// Permanently delete this entry and the media files it owns — its photos and
    /// its voice note (whose `deleteAudio` also removes the waveform sidecar). Used
    /// by the per-entry delete in the detail view and the composer's edit mode.
    func deleteWithMedia(in context: ModelContext) {
        for filename in photoFilenames { MediaStore.deletePhoto(filename) }
        if let voiceNoteFilename { MediaStore.deleteAudio(voiceNoteFilename) }
        context.delete(self)
        try? context.save()
    }
}
