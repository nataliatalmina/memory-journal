//
//  OnboardingContainerView.swift
//  MemoryJournal
//
//  The onboarding "coordinator": a single container that OWNS which step the
//  user is on and shows one child screen at a time. Each screen is its own view
//  and knows nothing about the others — it just calls a closure ("I'm done")
//  and the container moves to the next step. This keeps navigation in one place
//  and the screens simple and reusable.
//
//  Flow:  splash  →  view-mode selection  →  media permissions  →  (done → main app)
//

import SwiftUI

struct OnboardingContainerView: View {
    /// Called when the whole flow finishes. `RootView` uses it to flip the
    /// "has onboarded" flag and swap in the main tab bar.
    var onComplete: () -> Void

    /// The steps, in order. `@State` holds the current one; changing it re-renders.
    private enum Step {
        case splash
        case viewMode
        case permissions
    }
    @State private var step: Step = .splash

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            switch step {
            case .splash:
                // Auto-advance only (per your choice): no tap, it moves on itself.
                SplashView(onFinished: { step = .viewMode })
                    .transition(.opacity)

            case .viewMode:
                ViewModeSelectionView(onContinue: { step = .permissions })
                    .transition(.opacity)

            case .permissions:
                // Both "Maybe later" and "Continue" call onContinue → finish.
                MediaPermissionsView(onContinue: onComplete)
                    .transition(.opacity)
            }
        }
        // Gentle cross-fade between steps.
        .animation(.easeInOut(duration: 0.4), value: step)
    }
}

#Preview {
    OnboardingContainerView(onComplete: {})
}
