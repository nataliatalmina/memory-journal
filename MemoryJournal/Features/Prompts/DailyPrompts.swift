//
//  DailyPrompts.swift
//  MemoryJournal
//
//  Picks the 5 prompts shown on a given day — deterministically from the date,
//  so the set is STABLE for the whole day and REFRESHES at the next local
//  midnight, with no persistence and no background job.
//
//  How it works:
//   1. "The day" is the LOCAL calendar day (start-of-day in Calendar.current —
//      the same basis as Entry dates), so it flips at local midnight, DST-safe.
//   2. We turn that day into an integer "day number" (days since a fixed anchor).
//      Same day → same number; each day → +1.
//   3. That number seeds a small deterministic RNG (SplitMix64) and we SHUFFLE
//      the list's indices with it, then take the first 5. A shuffle gives 5
//      DISTINCT prompts (no repeats within a day), and because SplitMix64
//      "avalanches" (seed+1 produces a completely different sequence), each day's
//      five look unrelated to the day before — no obvious cycle.
//

import Foundation

enum DailyPrompts {
    /// The prompts to show for `date` (default: now), drawn from `list`.
    /// Returns up to `count` distinct prompts (fewer only if the list is smaller).
    static func selection(for date: Date = .now,
                          from list: [String] = PromptLibrary.all,
                          count: Int = 5,
                          calendar: Calendar = .current) -> [String] {
        guard !list.isEmpty else { return [] }
        let k = min(count, list.count)               // guard: list shorter than `count`

        var generator = SeededGenerator(seed: dayNumber(for: date, calendar: calendar))
        let order = Array(list.indices).shuffled(using: &generator)
        return order.prefix(k).map { list[$0] }
    }

    /// Days since a fixed anchor, counted in LOCAL calendar days (not raw seconds,
    /// so DST never shifts it). Stable for a whole local day; +1 the next day.
    static func dayNumber(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let anchor = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let day = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
        return UInt64(bitPattern: Int64(days))
    }
}

/// A tiny deterministic random number generator (SplitMix64). Same seed →
/// same sequence, with good bit-mixing so nearby seeds (consecutive days) give
/// very different results. Conforms to `RandomNumberGenerator` so it can drive
/// `shuffled(using:)`.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
