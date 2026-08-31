//
//  PhotoDayBoundsTests.swift
//  MemoryJournalTests
//
//  Covers `Date.localDayBounds(in:)` — turning a canonical (UTC-midnight) journal
//  day back into the span of real instants that day covers on the ground.
//
//  This is the boundary where entry dates meet the outside world: a photo's
//  capture time is a real instant in a real zone, not a canonical day, so the two
//  can only be compared after this conversion. Getting it wrong is the travel bug
//  pointing outwards — see `theUTCInstantIsNotTheDay` below, which builds the
//  wrong version deliberately and shows what it costs.
//
//  Same discipline as JournalDayTests: encode in one zone, read in another. A
//  test that used one calendar for both would pass no matter what we wrote.
//

import Testing
import Foundation
@testable import MemoryJournal

@MainActor
struct PhotoDayBoundsTests {

    // MARK: - Helpers

    func calendar(_ timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID)!
        return calendar
    }

    /// A canonical journal day (UTC midnight), built directly.
    func canonical(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A wall-clock instant in a named zone — stands in for "when a photo was taken".
    func instant(_ year: Int, _ month: Int, _ day: Int,
                 _ hour: Int, _ minute: Int = 0, _ second: Int = 0,
                 zone: String) -> Date {
        calendar(zone).date(from: DateComponents(year: year, month: month, day: day,
                                                 hour: hour, minute: minute, second: second))!
    }

    // MARK: - The trap this function exists to avoid

    @Test func theUTCInstantIsNotTheDay() throws {
        // 31 Aug 2025 as stored by the app. In Los Angeles that instant is 5pm on
        // the 30th — so using it directly as the start of a 24-hour window covers
        // the wrong day and a half.
        let day = canonical(2025, 8, 31)
        let losAngeles = calendar("America/Los_Angeles")

        let eveningOfThe31st = instant(2025, 8, 31, 20, zone: "America/Los_Angeles")
        let eveningOfThe30th = instant(2025, 8, 30, 18, zone: "America/Los_Angeles")

        // The WRONG version, written out so the failure mode is visible: take the
        // canonical instant as-is and add 24 hours.
        let naive = day..<day.addingTimeInterval(24 * 60 * 60)
        #expect(naive.contains(eveningOfThe30th))   // a memory of the wrong day, offered as the 31st
        #expect(!naive.contains(eveningOfThe31st))  // the real one, missed

        // The right version gets both the right way round.
        let bounds = try #require(day.localDayBounds(in: losAngeles))
        #expect(bounds.contains(eveningOfThe31st))
        #expect(!bounds.contains(eveningOfThe30th))
    }

    // MARK: - Covering the local day, in both directions from UTC

    @Test func boundsCoverTheWholeLocalDayWestOfUTC() throws {
        let losAngeles = calendar("America/Los_Angeles")
        let bounds = try #require(canonical(2025, 8, 31).localDayBounds(in: losAngeles))

        #expect(bounds.contains(instant(2025, 8, 31, 0, 0, 1, zone: "America/Los_Angeles")))
        #expect(bounds.contains(instant(2025, 8, 31, 12, zone: "America/Los_Angeles")))
        #expect(bounds.contains(instant(2025, 8, 31, 23, 59, 59, zone: "America/Los_Angeles")))

        #expect(!bounds.contains(instant(2025, 8, 30, 23, 59, 59, zone: "America/Los_Angeles")))
        #expect(!bounds.contains(instant(2025, 9, 1, 0, 0, 1, zone: "America/Los_Angeles")))
    }

    @Test func boundsCoverTheWholeLocalDayEastOfUTC() throws {
        // The mirror case. A photo taken at 00:30 in Tokyo is still the previous
        // day in UTC, so a UTC-based window would drop it.
        let tokyo = calendar("Asia/Tokyo")
        let bounds = try #require(canonical(2025, 8, 31).localDayBounds(in: tokyo))

        #expect(bounds.contains(instant(2025, 8, 31, 0, 30, zone: "Asia/Tokyo")))
        #expect(bounds.contains(instant(2025, 8, 31, 23, 30, zone: "Asia/Tokyo")))
        #expect(!bounds.contains(instant(2025, 8, 30, 23, 30, zone: "Asia/Tokyo")))
    }

    @Test func boundsAreHalfOpen() throws {
        // The boundary rule, stated on its own: the next day's first moment is the
        // range's end, and a range excludes its end. A photo taken exactly at
        // midnight belongs to the day that is starting, not the one that just ended.
        let london = calendar("Europe/London")
        let bounds = try #require(canonical(2026, 6, 10).localDayBounds(in: london))

        let midnightStarting = instant(2026, 6, 10, 0, zone: "Europe/London")
        let midnightEnding = instant(2026, 6, 11, 0, zone: "Europe/London")

        #expect(bounds.lowerBound == midnightStarting)
        #expect(bounds.upperBound == midnightEnding)
        #expect(bounds.contains(midnightStarting))
        #expect(!bounds.contains(midnightEnding))
    }

    @Test(arguments: ["Pacific/Honolulu", "America/St_Johns", "Europe/London",
                      "Asia/Kathmandu", "Asia/Tokyo", "Pacific/Auckland", "UTC"])
    func everyZoneGetsItsOwnMiddayOfThatDate(zone: String) {
        // Whatever the offset — including the half- and quarter-hour ones — noon
        // local time on the target date is always inside the bounds, and noon on
        // the neighbouring dates never is.
        let cal = calendar(zone)
        let bounds = canonical(2026, 3, 17).localDayBounds(in: cal)

        #expect(bounds?.contains(instant(2026, 3, 17, 12, zone: zone)) == true, "failed for \(zone)")
        #expect(bounds?.contains(instant(2026, 3, 16, 12, zone: zone)) == false, "failed for \(zone)")
        #expect(bounds?.contains(instant(2026, 3, 18, 12, zone: zone)) == false, "failed for \(zone)")
    }

    // MARK: - Daylight saving

    @Test func springForwardDayIsTwentyThreeHoursLong() throws {
        // US clocks jump forward on 8 March 2026, so that day is an hour short.
        // Hardcoding 24 hours anywhere in the conversion would overshoot into the
        // next day and offer a photo from the 9th as a memory of the 8th.
        let newYork = calendar("America/New_York")
        let bounds = try #require(canonical(2026, 3, 8).localDayBounds(in: newYork))

        #expect(bounds.upperBound.timeIntervalSince(bounds.lowerBound) == 23 * 60 * 60)
        #expect(!bounds.contains(instant(2026, 3, 9, 0, 30, zone: "America/New_York")))
    }

    @Test func fallBackDayIsTwentyFiveHoursLong() throws {
        // The mirror: 1 November 2026 has an extra hour, and the whole of it
        // belongs to that day — including the repeated 1am.
        let newYork = calendar("America/New_York")
        let bounds = try #require(canonical(2026, 11, 1).localDayBounds(in: newYork))

        #expect(bounds.upperBound.timeIntervalSince(bounds.lowerBound) == 25 * 60 * 60)
        #expect(bounds.contains(instant(2026, 11, 1, 23, 30, zone: "America/New_York")))
    }

    @Test func aDayWithNoMidnightStillWorks() throws {
        // São Paulo used to start DST at midnight, so 4 Nov 2018 had no 00:00 —
        // the day began at 01:00. This is why the conversion anchors on noon: ask
        // for a midnight that doesn't exist and you get a silently adjusted answer.
        let saoPaulo = calendar("America/Sao_Paulo")
        let bounds = try #require(canonical(2018, 11, 4).localDayBounds(in: saoPaulo))

        #expect(bounds.lowerBound == instant(2018, 11, 4, 1, zone: "America/Sao_Paulo"))
        #expect(bounds.contains(instant(2018, 11, 4, 1, 30, zone: "America/Sao_Paulo")))
        #expect(!bounds.contains(instant(2018, 11, 3, 23, 30, zone: "America/Sao_Paulo")))
    }

    // MARK: - Fed by the real look-back targets

    @Test func clampedLeapDayTargetGetsBoundsOnTheClampedDay() throws {
        // The look-back clamps 29 Feb to 28 Feb in non-leap years. The photo window
        // must land on the day that was actually clamped to — not on a phantom
        // 29 February — which it does for free by consuming `targetDates`.
        let targets = DateLookup().targetDates(matching: canonical(2024, 2, 29), mode: .years, count: 3)
        #expect(targets == [canonical(2024, 2, 29), canonical(2023, 2, 28), canonical(2022, 2, 28)])

        let london = calendar("Europe/London")
        let bounds = try #require(targets[1].localDayBounds(in: london))

        #expect(bounds.contains(instant(2023, 2, 28, 15, zone: "Europe/London")))
        #expect(!bounds.contains(instant(2023, 3, 1, 15, zone: "Europe/London")))
    }

    @Test func clampedShortMonthTargetGetsBoundsOnTheClampedDay() throws {
        // Same rule in month mode: the 31st clamps to the 30th where the month is
        // short, and the window follows it.
        let targets = DateLookup().targetDates(matching: canonical(2026, 5, 31), mode: .months, count: 2)
        #expect(targets == [canonical(2026, 5, 31), canonical(2026, 4, 30)])

        let tokyo = calendar("Asia/Tokyo")
        let bounds = try #require(targets[1].localDayBounds(in: tokyo))

        #expect(bounds.contains(instant(2026, 4, 30, 9, zone: "Asia/Tokyo")))
        #expect(!bounds.contains(instant(2026, 5, 1, 9, zone: "Asia/Tokyo")))
    }

    // MARK: - Round trip

    @Test func aPhotoTakenOnTheDayEncodesBackToThatDay() {
        // The two directions agree: take any instant inside the bounds, run it
        // through the encoder that files an entry, and you land on the day you
        // started from. This is what makes "an entry and a photo from the same
        // day" a meaningful statement.
        let losAngeles = calendar("America/Los_Angeles")
        let day = canonical(2025, 8, 31)
        let bounds = day.localDayBounds(in: losAngeles)

        for hour in [0, 6, 12, 18, 23] {
            let taken = instant(2025, 8, 31, hour, zone: "America/Los_Angeles")
            #expect(bounds?.contains(taken) == true, "failed at \(hour):00")
            #expect(taken.journalDay(in: losAngeles) == day, "failed at \(hour):00")
        }
    }
}
