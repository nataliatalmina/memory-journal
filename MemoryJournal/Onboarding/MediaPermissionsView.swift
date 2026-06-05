//
//  MediaPermissionsView.swift
//  MemoryJournal
//
//  Onboarding screen 3 — "access your media". Explains why the app may ask for
//  camera, photo-library, and microphone access, links to the privacy policy,
//  and offers a button to request each permission. NONE of this is required:
//  "Maybe later" and "Continue" both finish onboarding, and a user who grants
//  nothing can still write text entries. Permissions can be granted later.
//
//  Honesty: we only ASK iOS for permission here (via `MediaPermissions`). We do
//  not read, store, or transmit any media — matching the on-screen promise.
//

import SwiftUI
import UIKit   // only for opening the Settings app on a denied permission

struct MediaPermissionsView: View {
    var onContinue: () -> Void

    // Current status of each capability, shown on its button. Starts empty and
    // is filled in on appear (and updated after each request).
    @State private var statuses: [MediaCapability: PermissionStatus] = [:]
    @State private var showPrivacyPolicy = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Text("access your media")
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.top, Spacing.xxl)

                    // Body copy. (Fixed two small typos from the mockup —
                    // "access to your" → "access your", "won'y" → "won't" — while
                    // keeping the verbatim privacy promise.)
                    Text("You can add photos and voice notes to your entries. Memory Journal will need permission to access your camera, photo library, and microphone, but we won't store any of your media or personal data.")
                        .font(.kyoto(size: 16))
                        .foregroundStyle(Color.appBodyText)

                    Button { showPrivacyPolicy = true } label: {
                        Text("Read more about our privacy policy")
                            .font(.kyoto(size: 16))
                            .foregroundStyle(Color.appPrimary)
                            .underline()
                    }

                    VStack(spacing: Spacing.md) {
                        EnableButton(capability: .camera,
                                     label: "Enable Camera",
                                     status: statuses[.camera] ?? .notDetermined,
                                     onRequest: { request(.camera) })

                        EnableButton(capability: .photoLibrary,
                                     label: "Enable Photo Library",
                                     status: statuses[.photoLibrary] ?? .notDetermined,
                                     onRequest: { request(.photoLibrary) })

                        EnableButton(capability: .microphone,
                                     label: "Enable Microphone",
                                     status: statuses[.microphone] ?? .notDetermined,
                                     onRequest: { request(.microphone) })

                        Button(action: onContinue) {
                            Text("Maybe later")
                                .font(.kyoto(size: 16))
                                .foregroundStyle(Color.appPrimary)
                        }
                        .padding(.top, Spacing.xs)
                    }
                    .padding(.top, Spacing.md)
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
        // Read the current (possibly already-decided) status of each permission
        // when the screen appears, so buttons reflect reality.
        .onAppear(perform: refreshStatuses)
    }

    private func refreshStatuses() {
        for capability in MediaCapability.allCases {
            statuses[capability] = MediaPermissions.status(of: capability)
        }
    }

    /// Ask for one permission, then store the result so the button updates.
    private func request(_ capability: MediaCapability) {
        Task {
            statuses[capability] = await MediaPermissions.request(capability)
        }
    }
}

/// A full-width permission button. Per the design it has just two looks — the
/// label never changes, only the background colour:
///   • not yet granted (not determined OR denied) → sage `#5D909B` (appSecondary)
///   • granted                                     → teal `#005363` (appPrimary)
///
/// Behaviour behind those two looks:
///   • not determined → tap shows the system prompt
///   • denied         → tap deep-links to Settings (iOS only prompts once, so
///                       this is the only way to enable it afterwards)
///   • granted        → tap does nothing (already on)
private struct EnableButton: View {
    let capability: MediaCapability
    let label: String
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        Button(action: act) {
            Text(label)
                .font(.kyotoItalic(size: 16))   // italic serif button label
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(status == .granted ? Color.appPrimary : Color.appSecondary)
                .clipShape(.rect(cornerRadius: CornerRadius.button))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func act() {
        switch status {
        case .notDetermined: onRequest()
        case .denied:        openSettings()
        case .granted:       break   // already granted; nothing to do
        }
    }

    /// Short noun used for the VoiceOver label only ("Camera", "Photo Library", "Microphone").
    private var noun: String {
        switch capability {
        case .camera:       "Camera"
        case .photoLibrary: "Photo Library"
        case .microphone:   "Microphone"
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .notDetermined: "Enable \(noun)"
        case .granted:       "\(noun) enabled"
        case .denied:        "\(noun) access denied. Opens Settings."
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    MediaPermissionsView(onContinue: {})
        .background(Color.appBackground)
}
