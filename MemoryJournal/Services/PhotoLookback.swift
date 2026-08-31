//
//  PhotoLookback.swift
//  MemoryJournal
//
//  Finding a photo the user took on a given date, to fill a look-back slot where
//  they wrote no entry. The counterpart to `DateLookup`, and deliberately built
//  the same way: the decisions (which day, which photo) are PURE functions that
//  touch no framework and are unit-tested directly; the Photos query is a thin
//  layer on top.
//
//  Nothing here reads, copies, or stores an image. It works entirely in metadata
//  — an identifier, a capture date, two flags — and hands back a reference for
//  the UI to render straight from the user's library. That keeps the privacy
//  promise in CLAUDE.md literally true: keepsake never stores your media.
//
//  THE DATE RULE. Entry dates are canonical UTC midnights; `PHAsset.creationDate`
//  is a bare instant. They can only be compared after converting the canonical
//  day into local bounds — `Date.localDayBounds(in:)`, see Shared/JournalDay.swift.
//  Never hand a canonical instant to a Photos predicate directly.
//
//  KNOWN LIMITATION (deliberate). A photo is matched against the user's CURRENT
//  time zone, not the zone it was taken in. A photo taken at 00:30 in Tokyo reads
//  as the previous day once the user is home in London, so keepsake and the
//  Photos app can disagree about which day it belongs to. Reading true capture
//  time means pulling EXIF `DateTimeOriginal` for every candidate, which is far
//  too expensive for a screen that renders on every app open.
//

import Foundation
import Photos

/// One photo we could show, described in metadata only — no image data.
///
/// `Sendable` means "safe to hand between threads": the Photos query runs off the
/// main thread (a library scan shouldn't stutter the UI), so what it returns has
/// to be able to cross back safely. A struct of immutable values already is.
struct PhotoCandidate: Equatable, Identifiable, Sendable {
    /// Photos' own reference to this asset in the user's library on this device.
    /// It's all we ever persist about a photo (see `PhotoDismissals`).
    let localIdentifier: String
    let creationDate: Date
    let isFavorite: Bool
    let isScreenshot: Bool

    var id: String { localIdentifier }
}

struct PhotoLookback: Sendable {
    /// The calendar deciding what "that day" means on the ground — the user's own
    /// by default. Tests pass a fixed one to simulate travel.
    var calendar: Calendar

    /// Photos the user has dismissed and must never be shown again.
    var blocked: Set<String>

    init(calendar: Calendar = .current, blocked: Set<String> = PhotoDismissals.all()) {
        self.calendar = calendar
        self.blocked = blocked
    }

    // MARK: - Choosing one photo (pure — no Photos framework, unit-tested directly)

    /// Pick the single photo to show for one date, or `nil` if nothing qualifies.
    ///
    /// The rules, in order:
    ///  1. **Drop screenshots.** A screenshot of a train time is not a memory, and
    ///     they're numerous enough to swamp real photos on some days.
    ///  2. **Drop anything dismissed.** The user has said no to these.
    ///  3. **Prefer favourites.** If the user hearted anything that day, that's the
    ///     best evidence available of what mattered — use only those.
    ///  4. **Pick deterministically from what's left**, seeded by the date.
    ///
    /// Step 4 is why this takes a `seed` rather than calling `randomElement()`.
    /// The Journal screen re-renders often — every SwiftData change, every sheet
    /// presentation — and a fresh random pick each time would visibly swap the
    /// photo under the user's eyes. Seeding on the date makes the choice stable
    /// for the whole day, and different on the same date next year.
    nonisolated func select(from candidates: [PhotoCandidate], seed: Date) -> PhotoCandidate? {
        let usable = candidates.filter { !$0.isScreenshot && !blocked.contains($0.localIdentifier) }
        guard !usable.isEmpty else { return nil }

        let favourites = usable.filter(\.isFavorite)
        let pool = favourites.isEmpty ? usable : favourites

        // Sorted first so the pick can't depend on the order Photos happened to
        // return things in — the same day must give the same photo every time.
        let ordered = pool.sorted { $0.localIdentifier < $1.localIdentifier }
        return ordered[stableIndex(for: seed, count: ordered.count)]
    }

    /// A repeatable "random" index derived from the date.
    ///
    /// Note `Date.hashValue` would NOT work here: Swift seeds its hashing
    /// randomly per process, so the photo would change every time the app was
    /// relaunched. This uses the day number instead, run through Knuth's
    /// multiplicative hash so that consecutive days don't march through the
    /// candidates in lockstep (`&*` multiplies with wraparound instead of
    /// trapping on overflow).
    private nonisolated func stableIndex(for seed: Date, count: Int) -> Int {
        let dayNumber = Int((seed.timeIntervalSince1970 / 86_400).rounded(.down))
        let mixed = dayNumber &* 2_654_435_761
        return abs(mixed % count)
    }

    // MARK: - The Photos query

    /// Find one photo for each of `targetDates` that has one, keyed by the date.
    ///
    /// Dates with no usable photo are simply absent from the result — the caller
    /// renders nothing for those slots, exactly as it already does for a date with
    /// no entry.
    ///
    /// `nonisolated` means "not tied to the main actor". This project runs on the
    /// main actor by default, and scanning a photo library there would stutter the
    /// UI, so the work happens on a background task and only the small metadata
    /// result comes back.
    nonisolated func photos(for targetDates: [Date]) async -> [Date: PhotoCandidate] {
        // Convert each canonical day into the span of instants it covers locally.
        // Anything that fails to convert is dropped rather than guessed at.
        let windows: [(date: Date, bounds: Range<Date>)] = targetDates.compactMap { date in
            guard let bounds = date.localDayBounds(in: calendar) else { return nil }
            return (date, bounds)
        }
        guard !windows.isEmpty else { return [:] }

        let lookback = self
        return await Task.detached(priority: .userInitiated) {
            let grouped = lookback.fetchCandidates(for: windows)

            // Seed each pick with the DATE OF THE SLOT, not anything about the
            // photos themselves — that's what keeps the choice stable while the
            // user's library changes around it.
            // Assigning `nil` into a dictionary removes the key, so a date with no
            // usable photo simply never appears in the result.
            var chosen: [Date: PhotoCandidate] = [:]
            for (date, candidates) in grouped {
                chosen[date] = lookback.select(from: candidates, seed: date)
            }
            return chosen
        }.value
    }

    /// Fetch every image in the target windows in ONE query, grouped by window.
    ///
    /// One fetch with five OR'd date ranges, not five fetches: each round trip
    /// into the Photos database costs, and the windows are known up front.
    private nonisolated func fetchCandidates(for windows: [(date: Date, bounds: Range<Date>)]) -> [Date: [PhotoCandidate]] {
        let options = PHFetchOptions()

        let dateRanges = windows.map { window in
            NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                        window.bounds.lowerBound as NSDate,
                        window.bounds.upperBound as NSDate)
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            // Stills only. A video's poster frame would need a different fetch and
            // a different presentation, so it's out of scope rather than silently
            // half-supported.
            NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue),
            NSCompoundPredicate(orPredicateWithSubpredicates: dateRanges),
        ])
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: options)

        // Screenshot filtering happens HERE, in Swift, not in the predicate above:
        // Photos only accepts predicates on a limited set of keys, and the number
        // of photos taken on five specific dates is small enough that filtering
        // afterwards costs nothing.
        var grouped: [Date: [PhotoCandidate]] = [:]
        assets.enumerateObjects { asset, _, _ in
            guard let creationDate = asset.creationDate,
                  let window = windows.first(where: { $0.bounds.contains(creationDate) }) else { return }

            let candidate = PhotoCandidate(
                localIdentifier: asset.localIdentifier,
                creationDate: creationDate,
                isFavorite: asset.isFavorite,
                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
            )
            grouped[window.date, default: []].append(candidate)
        }
        return grouped
    }
}
