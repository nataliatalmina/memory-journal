//
//  AppLock.swift
//  MemoryJournal
//
//  Owns the app's locked/unlocked state for the optional App Lock feature
//  (Phase 6). One instance is created in `MemoryJournalApp` and injected into the
//  environment; `RootView` reads `isLocked` to overlay the lock screen, and drives
//  unlocking + re-locking from the scene phase.
//
//  `@Observable` makes SwiftUI re-render readers when `isLocked` changes.
//  `@MainActor` keeps all state changes on the main thread (they drive the UI).
//

import SwiftUI

@Observable
@MainActor
final class AppLock {
    /// When true, `RootView` covers everything with the lock screen. Also acts as
    /// the app-switcher privacy cover: because we set it on backgrounding, the
    /// snapshot iOS takes shows the lock screen, not the user's entries.
    private(set) var isLocked: Bool

    /// Guards against re-locking *while the system auth sheet is up* — presenting
    /// Face ID makes the app briefly `.inactive`, which would otherwise re-trigger
    /// a lock and fight the in-progress prompt.
    private var isAuthenticating = false

    init() {
        // Lock straight away on cold launch if the user has App Lock turned on.
        isLocked = AppLock.isEnabled
    }

    /// Live read of the persisted toggle (so turning it off in Settings stops
    /// future locking immediately, without us caching a stale copy).
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: PreferenceKey.appLockEnabled)
    }

    /// Run the system authentication prompt; on success, reveal the app.
    /// Safe to call repeatedly — it no-ops if already unlocked or mid-prompt.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let success = await BiometricLock.authenticate(reason: "Unlock your journal")
        isAuthenticating = false
        if success { isLocked = false }
    }

    /// React to the app moving between foreground and background. Re-locks when
    /// the app leaves the foreground so returning requires authentication again.
    func handleScenePhase(_ phase: ScenePhase) {
        guard AppLock.isEnabled, !isAuthenticating else { return }
        if phase == .inactive || phase == .background {
            isLocked = true
        }
    }
}
