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

    var body: some View {
        ZStack {
            if hasOnboarded {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView(onComplete: { hasOnboarded = true })
                    .transition(.opacity)
            }
        }
        // Cross-fade from onboarding into the app when the flag flips.
        .animation(.easeInOut(duration: 0.5), value: hasOnboarded)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(AppRouter())
}
