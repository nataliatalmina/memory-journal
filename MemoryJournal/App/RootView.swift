//
//  RootView.swift
//  MemoryJournal
//
//  The app's first view. It decides — on every launch — whether to show
//  onboarding or the main tab bar, based on a single persisted flag.
//
//  First launch:   hasOnboarded == false → show onboarding. When it finishes we
//                  set the flag true, which swaps in the tab bar.
//  Later launches: hasOnboarded == true  → go straight to the tab bar.
//

import SwiftUI
import SwiftData   // for `.modelContainer` in the preview

struct RootView: View {
    // `@AppStorage` binds this property to a UserDefaults value: reading it loads
    // the stored flag, and the view re-renders whenever it changes. Defaults to
    // `false` the very first time (the key doesn't exist yet).
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false

    // App Lock (Phase 6). `scenePhase` tells us when the app moves between
    // foreground and background, so we can re-lock and re-authenticate.
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if hasOnboarded {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView(onComplete: { hasOnboarded = true })
                    .transition(.opacity)
            }

            // When locked, cover everything. This also serves as the privacy
            // cover for the app-switcher snapshot (we lock on backgrounding).
            if appLock.isLocked {
                LockScreenView()
                    .transition(.opacity)
            }
        }
        // Cross-fade from onboarding into the app when the flag flips.
        .animation(.easeInOut(duration: 0.5), value: hasOnboarded)
        .animation(.easeInOut(duration: 0.25), value: appLock.isLocked)
        // Cold launch: if we opened locked, prompt for authentication right away.
        // (`onChange` below doesn't fire for the initial scene phase, so this
        // one-shot handles the first unlock.)
        .task {
            if appLock.isLocked { await appLock.unlock() }
        }
        .onChange(of: scenePhase) { _, phase in
            appLock.handleScenePhase(phase)
            // Returning to the foreground while locked → re-prompt automatically.
            if phase == .active && appLock.isLocked {
                Task { await appLock.unlock() }
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(AppRouter())
        .environment(AppLock())
}
