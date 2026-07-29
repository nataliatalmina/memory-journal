//
//  EntryDateMigration.swift
//  MemoryJournal
//
//  ONE-TIME repair of entry dates written before the canonical (UTC-midnight)
//  encoding — see Shared/JournalDay.swift for the background.
//
//  THE PROBLEM
//  Legacy entries stored midnight of their day *in the time zone the user was in
//  when they wrote it*. Change time zone and no query matches them any more, so
//  they vanish from every screen (they're still in the database — just
//  unreachable). Entries written while travelling are the ones affected.
//
//  THE RECOVERY
//  The legacy value is:
//
//      stored = utcMidnight(wallDate) − offsetOfWriteZone
//
//  UTC midnights are exact multiples of 86400, so the remainder
//  `r = stored mod 86400` IS that zone's offset, negated. The true answer is
//  therefore always one of just two candidates — the UTC midnight immediately
//  below the stored instant, or the one immediately above — and the offset each
//  one implies tells us which is real:
//
//      floor → implies offset −r            (a zone behind UTC)
//      ceil  → implies offset +(86400 − r)  (a zone ahead of UTC)
//
//  Exactly one of those normally lands inside the real range of world time-zone
//  offsets (−12h … +14h), which makes the recovery exact — including for the
//  half- and quarter-hour zones (India +5:30, Nepal +5:45, Chatham +12:45).
//
//  THE ONE AMBIGUOUS CASE
//  When `r` falls between 10h and 12h both candidates are plausible: +12 can't be
//  told apart from −12, +13 from −11, +14 from −10. That affects only entries
//  written at UTC+12 or further east (New Zealand, Fiji, Kiribati). Those land one
//  day out rather than disappearing, and `ambiguousCount` reports them. Everything
//  else recovers exactly.
//
//  SAFETY
//   • Runs once, guarded by a version flag in UserDefaults.
//   • Idempotent anyway: a canonical date has `r == 0` and is left alone, so a
//     second run is a no-op even if the flag were lost.
//   • Writes an audit file (old → new, per entry) into Application Support before
//     saving, so any mistake can be traced and reversed. It stays on-device, in
//     the app's own container — the privacy promise is unaffected.
//

import Foundation
import SwiftData

enum EntryDateMigration {
    /// Bump this if a future migration needs to run.
    static let currentVersion = 1
    private static let versionKey = PreferenceKey.entryDateStorageVersion

    /// Plausible real-world UTC offsets, in seconds: Baker Island (−12) through
    /// the Line Islands (+14).
    private static let offsetRange = -12 * 3600 ... 14 * 3600
    private static let secondsPerDay: TimeInterval = 86400

    struct Result {
        var converted = 0
        var alreadyCanonical = 0
        var ambiguousCount = 0
    }

    /// Run the migration if it hasn't run yet. Safe to call on every launch.
    @discardableResult
    static func runIfNeeded(_ context: ModelContext,
                            defaults: UserDefaults = .standard) -> Result? {
        guard defaults.integer(forKey: versionKey) < currentVersion else { return nil }

        let result = migrate(context)
        defaults.set(currentVersion, forKey: versionKey)
        return result
    }

    /// The migration proper. Exposed (rather than private) so tests can run it
    /// against an in-memory store without touching UserDefaults.
    @discardableResult
    static func migrate(_ context: ModelContext) -> Result {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        var result = Result()
        var audit: [AuditRecord] = []

        // The device's offset today, used only to break the rare tie below.
        let deviceOffset = TimeZone.current.secondsFromGMT(for: .now)

        for entry in entries {
            let old = entry.date
            guard !old.isCanonicalJournalDay else {
                result.alreadyCanonical += 1
                continue
            }

            let recovery = recover(old, deviceOffset: deviceOffset)
            entry.date = recovery.date
            result.converted += 1
            if recovery.wasAmbiguous { result.ambiguousCount += 1 }

            audit.append(AuditRecord(id: entry.id.uuidString,
                                     old: old,
                                     new: recovery.date,
                                     ambiguous: recovery.wasAmbiguous))
        }

        if !audit.isEmpty {
            writeAudit(audit)
            try? context.save()
        }
        return result
    }

    // MARK: - The arithmetic (pure — unit-tested directly)

    struct Recovery: Equatable {
        var date: Date
        var wasAmbiguous: Bool
    }

    /// Recover the canonical journal day from a legacy local-midnight instant.
    /// See the file header for the derivation.
    static func recover(_ stored: Date, deviceOffset: Int) -> Recovery {
        let t = stored.timeIntervalSince1970
        // Positive remainder, so this is correct for pre-1970 dates too (where
        // `t` is negative and truncating division would round the wrong way).
        let r = t - secondsPerDay * (t / secondsPerDay).rounded(.down)
        guard r != 0 else { return Recovery(date: stored, wasAmbiguous: false) }

        let floorMidnight = Date(timeIntervalSince1970: t - r)
        let ceilMidnight  = Date(timeIntervalSince1970: t - r + secondsPerDay)
        let floorOffset = Int(-r)                        // zone behind UTC
        let ceilOffset  = Int(secondsPerDay - r)         // zone ahead of UTC

        switch (offsetRange.contains(floorOffset), offsetRange.contains(ceilOffset)) {
        case (true, false):
            return Recovery(date: floorMidnight, wasAmbiguous: false)
        case (false, true):
            return Recovery(date: ceilMidnight, wasAmbiguous: false)
        default:
            // Both plausible (or neither, which shouldn't occur). Prefer the zone
            // the device is in now — most entries are written at home — and
            // otherwise take the western reading, which covers the more populated
            // side of the ±12 line.
            if ceilOffset == deviceOffset {
                return Recovery(date: ceilMidnight, wasAmbiguous: true)
            }
            return Recovery(date: floorMidnight, wasAmbiguous: true)
        }
    }

    // MARK: - Audit trail

    private struct AuditRecord: Codable {
        let id: String
        let old: Date
        let new: Date
        let ambiguous: Bool
    }

    /// Write the before/after record next to the app's other data. Best-effort:
    /// failing to write the audit must never block the repair itself.
    private static func writeAudit(_ records: [AuditRecord]) {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true) else { return }
        let url = support.appendingPathComponent("entry-date-migration-v\(currentVersion).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
