//
//  PrivacyPolicyView.swift
//  MemoryJournal
//
//  A simple in-app, scrollable privacy policy reached from the "Read more about
//  our privacy policy" link on the permissions screen.
//
//  ⚠️ DRAFT TEXT. This wording is a placeholder written to accurately describe
//  what the app currently does (local-only, on-device, no servers). It is NOT
//  reviewed legal copy — replace it with finalised wording before shipping.
//  Do not add claims here that the code doesn't actually honour.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss   // lets the sheet close itself

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Label("DRAFT — placeholder wording, not yet reviewed.", systemImage: "exclamationmark.triangle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSurface)
                        .clipShape(.rect(cornerRadius: CornerRadius.button))

                    section(
                        "Your memories stay on your device",
                        "Everything you write, and any photos or voice notes you add, is stored only on this device using Apple's on-device database. We do not run any server that receives your journal content."
                    )
                    section(
                        "No accounts, no tracking",
                        "Memory Journal has no sign-up and no user accounts. We do not use analytics, advertising, or third-party SDKs, and we do not profile you or sell data."
                    )
                    section(
                        "Photos and voice notes",
                        "If you choose to add a photo or voice note, it is saved inside the app's own private storage on this device. It is never uploaded or shared by the app."
                    )
                    section(
                        "Permissions you control",
                        "Camera, photo-library, and microphone access are optional and only used to add media you choose to your entries. You can grant or revoke them at any time in the Settings app. The app works for text entries without any of them."
                    )
                    section(
                        "Encryption at rest",
                        "Your data benefits from iOS Data Protection, which encrypts files on disk while the device is locked. Keep a device passcode enabled to get this protection."
                    )
                    section(
                        "If we ever add iCloud sync",
                        "Any future sync would be opt-in and would use your own private iCloud (Apple's end-to-end CloudKit), never our own servers. Until you explicitly turn such a feature on, your data stays on this device."
                    )
                    section(
                        "Contact",
                        "Questions about privacy can be directed to the developer. (Placeholder — add a real contact before release.)"
                    )
                }
                .padding(Spacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("privacy policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// One titled paragraph.
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.kyoto(size: 18))
                .foregroundStyle(Color.appPrimary)
            Text(body)
                .font(.kyoto(size: 15))
                .foregroundStyle(Color.appBodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
