//
//  PhotoLookbackTests.swift
//  MemoryJournalTests
//
//  Covers `PhotoLookback.select` — which photo gets shown for a date, given the
//  ones taken that day.
//
//  Only the pure half is testable: the Photos query itself needs a real photo
//  library, which is exactly why the decisions live behind a `PHAsset`-free
//  boundary. What's tested here is everything that decides what the user sees.
//

import Testing
import Foundation
@testable import MemoryJournal

@MainActor
struct PhotoLookbackTests {

    // MARK: - Helpers

    func canonical(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func candidate(_ id: String,
                   favourite: Bool = false,
                   screenshot: Bool = false,
                   hour: Int = 12) -> PhotoCandidate {
        PhotoCandidate(localIdentifier: id,
                       creationDate: canonical(2025, 8, 31).addingTimeInterval(TimeInterval(hour * 3600)),
                       isFavorite: favourite,
                       isScreenshot: screenshot)
    }

    /// A lookback with nothing dismissed.
    var lookback: PhotoLookback { PhotoLookback(calendar: .current, blocked: []) }

    // MARK: - Nothing to show

    @Test func noCandidatesGivesNoPhoto() {
        #expect(lookback.select(from: [], seed: canonical(2025, 8, 31)) == nil)
    }

    @Test func aDayOfNothingButScreenshotsGivesNoPhoto() {
        // Better to show nothing than to offer a screenshot as a memory.
        let all = [candidate("A", screenshot: true), candidate("B", screenshot: true)]
        #expect(lookback.select(from: all, seed: canonical(2025, 8, 31)) == nil)
    }

    @Test func aDayOfNothingButDismissedPhotosGivesNoPhoto() {
        let blocked = PhotoLookback(calendar: .current, blocked: ["A", "B"])
        let all = [candidate("A"), candidate("B")]
        #expect(blocked.select(from: all, seed: canonical(2025, 8, 31)) == nil)
    }

    // MARK: - Filtering

    @Test func screenshotsAreNeverChosen() {
        let all = [candidate("A", screenshot: true),
                   candidate("B", screenshot: true),
                   candidate("C")]
        #expect(lookback.select(from: all, seed: canonical(2025, 8, 31))?.localIdentifier == "C")
    }

    @Test func dismissedPhotosAreNeverChosen() {
        // The whole point of the dismiss affordance: it has to hold across every
        // future render, not just the one where the user tapped it.
        let blocked = PhotoLookback(calendar: .current, blocked: ["A", "B"])
        let all = [candidate("A"), candidate("B"), candidate("C")]
        #expect(blocked.select(from: all, seed: canonical(2025, 8, 31))?.localIdentifier == "C")
    }

    // MARK: - Ranking

    @Test func aFavouriteBeatsAnOrdinaryPhoto() {
        // The user hearting something is the best signal we have about what
        // mattered that day.
        let all = [candidate("A"), candidate("B", favourite: true), candidate("C")]
        #expect(lookback.select(from: all, seed: canonical(2025, 8, 31))?.localIdentifier == "B")
    }

    @Test func aDismissedFavouriteDoesNotBeatAnOrdinaryPhoto() {
        // Dismissal outranks favouriting: "don't show me this" is the more recent
        // and more specific instruction.
        let blocked = PhotoLookback(calendar: .current, blocked: ["B"])
        let all = [candidate("A"), candidate("B", favourite: true)]
        #expect(blocked.select(from: all, seed: canonical(2025, 8, 31))?.localIdentifier == "A")
    }

    @Test func aFavouriteScreenshotIsStillAScreenshot() {
        let all = [candidate("A"), candidate("B", favourite: true, screenshot: true)]
        #expect(lookback.select(from: all, seed: canonical(2025, 8, 31))?.localIdentifier == "A")
    }

    @Test func favouritesAreChosenFromAmongThemselves() {
        let all = [candidate("A"), candidate("B", favourite: true),
                   candidate("C", favourite: true), candidate("D")]
        let chosen = lookback.select(from: all, seed: canonical(2025, 8, 31))
        #expect(chosen?.isFavorite == true)
    }

    // MARK: - Stability (why this isn't randomElement())

    @Test func thePickIsStableForTheSameDay() {
        // The Journal screen re-renders constantly. If this weren't stable the
        // photo would visibly swap under the user mid-scroll.
        let all = [candidate("A"), candidate("B"), candidate("C"), candidate("D")]
        let day = canonical(2025, 8, 31)

        let first = lookback.select(from: all, seed: day)
        for _ in 0..<20 {
            #expect(lookback.select(from: all, seed: day) == first)
        }
    }

    @Test func thePickDoesNotDependOnTheOrderPhotosCameBackIn() {
        // Photos' fetch order is not ours to rely on. Same day, same set, same
        // answer — however it arrived.
        let all = [candidate("A"), candidate("B"), candidate("C"), candidate("D")]
        let day = canonical(2025, 8, 31)

        let forwards = lookback.select(from: all, seed: day)
        let backwards = lookback.select(from: all.reversed(), seed: day)
        let shuffled = lookback.select(from: all.shuffled(), seed: day)

        #expect(forwards == backwards)
        #expect(forwards == shuffled)
    }

    @Test func differentDaysCanGetDifferentPhotos() {
        // The flip side of stability: the choice must actually vary, or "random"
        // is a lie and the same photo returns every year.
        let all = (1...8).map { candidate("photo-\($0)") }

        let picks = Set((0..<40).compactMap { dayOffset -> String? in
            let day = canonical(2025, 1, 1).addingTimeInterval(TimeInterval(dayOffset * 86_400))
            return lookback.select(from: all, seed: day)?.localIdentifier
        })

        #expect(picks.count > 1)
    }

    @Test func consecutiveDaysDoNotMarchThroughInLockstep() {
        // Guards the hash mixing in `stableIndex`. Without it, consecutive day
        // numbers produce consecutive indices, and with a two-photo day the
        // choice would just alternate — visibly patterned rather than arbitrary.
        let all = [candidate("A"), candidate("B")]
        let start = canonical(2025, 1, 1)

        let sequence = (0..<6).map { dayOffset -> String in
            let day = start.addingTimeInterval(TimeInterval(dayOffset * 86_400))
            return lookback.select(from: all, seed: day)!.localIdentifier
        }

        #expect(Set(sequence).count == 2)   // both photos get used across the run
    }

    @Test func aSinglePhotoIsAlwaysTheAnswer() {
        // Guards the modulo: with one candidate the index can only be 0, and a
        // negative day number (a date before 1970) must not produce a negative one.
        let only = [candidate("A")]
        #expect(lookback.select(from: only, seed: canonical(2025, 8, 31))?.localIdentifier == "A")
        #expect(lookback.select(from: only, seed: canonical(1962, 3, 4))?.localIdentifier == "A")
    }

    @Test func datesBeforeEpochStillChooseValidly() {
        // The look-back can only reach five years back, so this can't happen in
        // the app — but a negative day number through `abs(mixed % count)` is
        // exactly the kind of thing that traps at runtime, so it's pinned.
        let all = [candidate("A"), candidate("B"), candidate("C")]
        #expect(lookback.select(from: all, seed: canonical(1955, 11, 5)) != nil)
    }
}
