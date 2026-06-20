//
//  LockScreenView.swift
//  MemoryJournal
//
//  The full-screen cover shown while the app is locked (Phase 6 App Lock). It
//  hides all journal content (so the app-switcher snapshot is safe too) and
//  offers an "Unlock" button that re-runs the system authentication prompt.
//
//  `RootView` auto-triggers authentication when this appears / on foreground; the
//  button is the manual retry path (e.g. after a cancelled or failed scan).
//

import SwiftUI

struct LockScreenView: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        ZStack {
            // Opaque background so nothing behind shows through.
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                GIFImage(resourceName: "Loading")
                    .frame(width: 110, height: 78)
                    .accessibilityHidden(true)

                Text("memory journal")
                    .font(.kyoto(size: 32))
                    .foregroundStyle(Color.appPrimary)

                Text("Your journal is locked.")
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appBodyText)

                AppButton(title: "Unlock") {
                    Task { await appLock.unlock() }
                }
                .frame(maxWidth: 300)
                .padding(.top, Spacing.sm)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.lg)
        }
    }
}

#Preview {
    LockScreenView()
        .environment(AppLock())
}
