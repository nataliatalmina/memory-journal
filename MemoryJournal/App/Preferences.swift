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

    /// `true` when the user has turned on App Lock (Phase 6): require Face ID /
    /// Touch ID / passcode to open the app. Defaults to `false` (off). Read by
    /// `AppLock` to decide whether to lock on launch and when backgrounded.
    static let appLockEnabled = "appLockEnabled"

    /// Which entry-date storage format the local store has been migrated to (see
    /// `EntryDateMigration`). `0`/absent means "still the original time-zone
    /// dependent encoding"; the migration bumps it once it has repaired the store.
    static let entryDateStorageVersion = "entryDateStorageVersion"

    /// `true` when the user has opted into photo look-back (Phase 7): where a
    /// look-back slot has no entry, show a photo taken on that date instead.
    /// Written by onboarding's look-back screen and by Settings. Defaults to
    /// `false` — this feature is opt-in and stays off until asked for.
    ///
    /// This is the user's INTENT only. It is deliberately separate from the iOS
    /// photo-library permission, which is a different question asked at a
    /// different moment: this flag can be `true` while access is not yet granted
    /// (that's the state that shows the in-context card on the Journal screen).
    static let photoLookbackEnabled = "photoLookbackEnabled"

    /// Identifiers of photos the user has dismissed from their look-back, so we
    /// never offer them again. See `PhotoDismissals` below for the accessors.
    static let dismissedPhotoIdentifiers = "dismissedPhotoIdentifiers"
}

/// Reading and writing the dismissed-photo list.
///
/// Why this isn't `@AppStorage`: that property wrapper handles single values
/// (`Bool`, `String`, `Int`, `RawRepresentable`), not arrays — so the list gets
/// its own tiny accessor instead of a wrapper fought into shape.
///
/// What's stored is only Photos' own **local identifiers** — short opaque strings
/// like `"B84E8479-…/L0/001"` that name a photo inside the user's library on this
/// device. No image data, no dates, nothing about what the photo shows, and
/// nothing that means anything off this device. That keeps the privacy promise
/// intact (CLAUDE.md): dismissing a photo stores a reference, never a copy.
enum PhotoDismissals {
    /// Every dismissed identifier. A `Set` because the only question ever asked
    /// of it is "is this one in here?", which a set answers instantly however
    /// long the list grows.
    ///
    /// `defaults` is injectable so tests can use a throwaway store instead of
    /// writing into the real app's preferences; day-to-day code omits it.
    static func all(in defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: PreferenceKey.dismissedPhotoIdentifiers) ?? [])
    }

    /// Hide this photo from the look-back for good. Dismissing the same photo
    /// twice is harmless — the list holds one of each.
    static func add(_ identifier: String, in defaults: UserDefaults = .standard) {
        var identifiers = defaults.stringArray(forKey: PreferenceKey.dismissedPhotoIdentifiers) ?? []
        guard !identifiers.contains(identifier) else { return }
        identifiers.append(identifier)
        defaults.set(identifiers, forKey: PreferenceKey.dismissedPhotoIdentifiers)
    }

    /// Forget every dismissal, so those photos can appear again. Used by the
    /// Settings row of the same name, and by "Delete all data".
    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: PreferenceKey.dismissedPhotoIdentifiers)
    }

    /// How many photos are currently hidden — shown next to the Settings row so
    /// the user can tell whether there's anything to forget.
    static func count(in defaults: UserDefaults = .standard) -> Int {
        all(in: defaults).count
    }
}
