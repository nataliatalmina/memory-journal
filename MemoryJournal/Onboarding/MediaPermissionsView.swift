//
//  MediaPermissionsView.swift
//  MemoryJournal
//
//  Onboarding screen 3 — introduces photos and voice notes, states the privacy
//  promise, and links to the privacy policy. That's all it does.
//
//  IMPORTANT — this screen must NOT request any permission, and must not talk
//  the user into granting one. App Review rejected build 1.0 (3) under guideline
//  5.1.1(iv) because the earlier version showed a custom message with "Enable
//  Camera / Photo Library / Microphone" buttons and a "Maybe later" escape.
//  Apple's rule: a custom message shown *before* a system permission prompt may
//  not use persuasive wording, and must always lead to the real prompt. Since no
//  prompt follows this screen any more, the rule no longer applies to it.
//
//  Camera and microphone are requested IN CONTEXT instead — the moment the user
//  taps those icons in the composer (see `ComposerView.tapCamera` /
//  `startVoiceNote`). The photo library needs no permission at all: `PhotosPicker`
//  runs out-of-process, so the app only ever receives the images the user picked.
//

import SwiftUI

struct MediaPermissionsView: View {
    var onContinue: () -> Void

    @State private var showPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Text("photos and voice notes")
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.top, Spacing.xxl)

                    // Describes the feature and keeps the verbatim privacy
                    // promise from the original design. Deliberately does NOT
                    // mention granting permission or ask for anything — iOS will
                    // ask on its own, later, at the moment it's actually needed.
                    Text("You can add photos and voice notes to your entries. Everything you write and record stays on this device — we won't store any of your media or personal data.")
                        .font(.kyoto(size: 16))
                        .foregroundStyle(Color.appBodyText)

                    Button { showPrivacyPolicy = true } label: {
                        Text("Read more about our privacy policy")
                            .font(.kyoto(size: 16))
                            .foregroundStyle(Color.appPrimary)
                            .underline()
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }

            AppButton(title: "Continue", action: onContinue)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
}

#Preview {
    MediaPermissionsView(onContinue: {})
        .background(Color.appBackground)
}
