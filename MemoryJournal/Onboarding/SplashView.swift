//
//  SplashView.swift
//  MemoryJournal
//
//  Onboarding screen 1 — the loading/splash. The animated book GIF, the
//  "memory journal" wordmark, and a two-line tagline that fades in line by line.
//  It AUTO-ADVANCES on its own after the intro (your chosen behaviour: no tap).
//

import SwiftUI

struct SplashView: View {
    /// Called once the intro has played, to move to the next step.
    var onFinished: () -> Void

    // Drives the line-by-line fade-in. Each flag, when set true (inside
    // `withAnimation`), fades its line from invisible to visible. The tagline
    // lines have separate flags so they appear one after the other.
    @State private var showWordmark = false
    @State private var showTaglineLine1 = false
    @State private var showTaglineLine2 = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            GIFImage(resourceName: "Loading")
                .frame(width: 260, height: 260)   // the GIF is square; scaled down from 2048²

            VStack(spacing: Spacing.lg) {
                Text("memory journal")
                    // Wordmark. The Figma's slightly greener teal (#005d4f) was a
                    // mistake; we use the palette's single `appPrimary` (#005363).
                    // (Owner-confirmed — keep one teal everywhere for consistency.)
                    .font(.kyoto(size: 44))
                    .foregroundStyle(Color.appPrimary)
                    .opacity(showWordmark ? 1 : 0)

                VStack(spacing: Spacing.xs) {
                    Text("Our memories make us human")
                        .opacity(showTaglineLine1 ? 1 : 0)
                    Text("Don't let them fade away")
                        .opacity(showTaglineLine2 ? 1 : 0)
                }
                .font(.kyoto(size: 18))
                .foregroundStyle(Color.appBodyText)
            }
            .multilineTextAlignment(.center)

            Spacer()
            Spacer()   // bias the content slightly above centre, like the design
        }
        .padding(.horizontal, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.task` runs when the view appears and is automatically CANCELLED if the
        // view goes away — so the timing here is cancel-safe.
        .task {
            do {
                // Fade in each piece in sequence: wordmark, then tagline line 1,
                // then tagline line 2, then hold briefly before advancing.
                withAnimation(.easeIn(duration: 0.8)) { showWordmark = true }
                try await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeIn(duration: 0.7)) { showTaglineLine1 = true }
                try await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeIn(duration: 0.7)) { showTaglineLine2 = true }
                try await Task.sleep(for: .seconds(1.8))
            } catch {
                // Cancelled (view dismissed) → bail out without advancing.
                return
            }
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
