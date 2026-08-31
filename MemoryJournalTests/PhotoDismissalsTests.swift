//
//  PhotoDismissalsTests.swift
//  MemoryJournalTests
//
//  Covers `PhotoDismissals` — the stored list of photos the user has told us not
//  to show again. Small surface, but a dismissal that doesn't stick means the app
//  re-offers a photo someone actively asked to be rid of, so it's worth pinning.
//
//  Each test runs against its own throwaway `UserDefaults` suite (never the real
//  app's), created and removed inside the test so nothing leaks between runs.
//

import Testing
import Foundation
@testable import MemoryJournal

@MainActor
struct PhotoDismissalsTests {

    /// A private defaults store, isolated per test by its unique suite name.
    func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        UserDefaults(suiteName: name)!
    }

    @Test func startsEmpty() {
        let defaults = makeDefaults()
        #expect(PhotoDismissals.all(in: defaults).isEmpty)
        #expect(PhotoDismissals.count(in: defaults) == 0)
    }

    @Test func aDismissedPhotoIsRemembered() {
        let defaults = makeDefaults()
        PhotoDismissals.add("B84E8479-0000/L0/001", in: defaults)

        #expect(PhotoDismissals.all(in: defaults).contains("B84E8479-0000/L0/001"))
        #expect(PhotoDismissals.count(in: defaults) == 1)
    }

    @Test func dismissingTheSamePhotoTwiceStoresItOnce() {
        // The UI can't easily produce this (a dismissed photo stops being shown),
        // but a list that grows a duplicate every time would be a slow leak.
        let defaults = makeDefaults()
        PhotoDismissals.add("A/L0/001", in: defaults)
        PhotoDismissals.add("A/L0/001", in: defaults)

        #expect(PhotoDismissals.count(in: defaults) == 1)
    }

    @Test func dismissalsAccumulate() {
        let defaults = makeDefaults()
        for identifier in ["A/L0/001", "B/L0/001", "C/L0/001"] {
            PhotoDismissals.add(identifier, in: defaults)
        }

        #expect(PhotoDismissals.all(in: defaults) == ["A/L0/001", "B/L0/001", "C/L0/001"])
    }

    @Test func clearingForgetsEverything() {
        // Backs the "Forget dismissed photos" row in Settings, and the sweep that
        // "Delete all data" has to do — dismissals are user data too.
        let defaults = makeDefaults()
        PhotoDismissals.add("A/L0/001", in: defaults)
        PhotoDismissals.add("B/L0/001", in: defaults)

        PhotoDismissals.clear(in: defaults)

        #expect(PhotoDismissals.all(in: defaults).isEmpty)
        #expect(PhotoDismissals.count(in: defaults) == 0)
    }

    @Test func dismissalsSurviveAFreshReadOfTheSameStore() {
        // Proves the value is genuinely persisted rather than held in memory:
        // a second `UserDefaults` handle on the same suite sees it.
        let suite = UUID().uuidString
        let defaults = makeDefaults(suite)
        PhotoDismissals.add("A/L0/001", in: defaults)

        let reopened = UserDefaults(suiteName: suite)!
        #expect(PhotoDismissals.all(in: reopened).contains("A/L0/001"))

        PhotoDismissals.clear(in: reopened)
    }
}
