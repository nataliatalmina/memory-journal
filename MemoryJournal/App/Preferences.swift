//
//  Preferences.swift
//  MemoryJournal
//
//  Central home for the small set of user-defaults keys the app persists.
//  Keeping the key strings in one place avoids typos (a mistyped key silently
//  reads/writes the wrong setting) and gives us one spot to see everything we
//  store in UserDefaults.
//
//  These are *preferences* (small flags/choices), not journal data. Journal
//  content lives in SwiftData; nothing here leaves the device.
//

import Foundation

enum PreferenceKey {
    /// `true` once the user has finished onboarding. Gates first-launch vs. later
    /// launches (see `RootView`).
    static let hasOnboarded = "hasOnboarded"

    /// The user's chosen look-back window (`LookbackMode`). Written first during
    /// onboarding (screen 2) and later editable in Settings (Phase 6). The
    /// journal's same-date query reads this to know how far back to look.
    static let lookbackMode = "lookbackMode"
}
