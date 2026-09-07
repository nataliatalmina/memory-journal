//
//  PrivacyPolicyView.swift
//  MemoryJournal
//
//  The in-app, scrollable privacy policy, reached from the "Read more about our
//  privacy policy" link on the onboarding permissions screen and from Settings.
//
//  This wording is the published policy. It is written to accurately describe what
//  the app actually does (local-only, on-device, no servers, no tracking). Keep it
//  in sync with the code: if a change would alter how data is handled, update this
//  text (and the hosted web copy) to match before shipping.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss   // lets the sheet close itself

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Effective date: 7 September 2026")
                        .font(.kyoto(size: 13))
                        .foregroundStyle(Color.appBodyText.opacity(0.7))

                    Text("keepsake is designed so your memories stay yours. This policy explains, in plain language, what the app does and doesn't do with your information. The short version: everything you write and add stays on your device, and we run no servers that receive your journal.")
                        .font(.kyoto(size: 15))
                        .foregroundStyle(Color.appBodyText)
                        .fixedSize(horizontal: false, vertical: true)

                    section(
                        "Your memories stay on your device",
                        "Everything you create in keepsake — your entries, their titles, dates, and any photos or voice notes you attach — is stored only on your device, in the app's private storage, using Apple's on-device database. We do not operate any server that receives, stores, or can read your journal content. Your memories are never uploaded to us or to anyone else by the app."
                    )
                    section(
                        "No account, no sign-up",
                        "keepsake has no accounts and no sign-up. You don't give us a name, email, or password to use the app, and we don't create a profile about you."
                    )
                    section(
                        "We don't track you or use analytics",
                        "The app contains no analytics, advertising, tracking technologies, or third-party SDKs. We don't measure how you use the app, and we don't build advertising or behavioural profiles. We don't sell, rent, or share your data — no journal data leaves your device for us to share in the first place."
                    )
                    section(
                        "Photos and voice notes",
                        "If you choose to add a photo or voice note to an entry, the file is saved inside the app's own private storage on your device. These files are never uploaded or shared by the app. Your entry stores only a reference to each file — never a copy on any server."
                    )
                    section(
                        "Photos from this date",
                        """
                        On days you didn't write anything, keepsake can show a photo you took that day, in the place a past entry would appear. This is off unless you turn it on — in onboarding, or in Settings — and you can turn it off again at any time, which stops the app looking at your library at all.

                        When it is on, keepsake asks iOS for permission to read your photo library, then looks for photos taken on the dates you're viewing. To choose one it reads each candidate's date, whether you marked it a favourite, and whether it is a screenshot (screenshots are skipped). Nothing else about your library is examined.

                        Photos found this way are displayed straight from your library. They are never copied into the app, never stored by it, and never uploaded. If a photo isn't held on your device, iOS may fetch it from your own iCloud Photos in order to display it — that happens between your device and Apple, not through us.

                        If you hide a photo you'd rather not see, keepsake records only that photo's identifier — the reference iOS uses to name it on this device — so it isn't offered again. You can clear that list with "Forget Hidden Photos" in Settings, and "Delete All Data" clears it too.
                        """
                    )
                    section(
                        "Permissions you control",
                        """
                        keepsake may ask for access to your camera, photo library, and microphone. These are entirely optional and are used only to add media you choose to your own entries:

                        • Camera — to take a photo for an entry.
                        • Photo library — to add a photo you select to an entry, and, if you turn on photo look-back, to find photos taken on the date you're viewing.
                        • Microphone — to record a voice note for an entry.

                        You can grant or revoke any of these at any time in the iOS Settings app, and the app works fully for text entries without any of them. Granting a permission does not send anything to us.
                        """
                    )
                    section(
                        "App Lock and Face ID / Touch ID",
                        "If you turn on App Lock, keepsake asks iOS to confirm it's you (with Face ID, Touch ID, or your device passcode) before opening. This check is performed entirely by iOS. The app never sees, receives, or stores your face, fingerprint, or passcode — that information stays protected by Apple's Secure Enclave."
                    )
                    section(
                        "Encryption and device security",
                        "Your data benefits from iOS Data Protection, which encrypts files on disk while your device is locked. Keep a device passcode enabled (and App Lock, if you wish) for the strongest protection."
                    )
                    section(
                        "Keeping and deleting your data",
                        "Your entries stay on your device until you delete them. You can remove everything at once with \"Delete All Data\" in Settings, or delete the app — either of which permanently removes the corresponding data from your device. Because we hold no copy of your data, deletion is final and cannot be recovered by us."
                    )
                    section(
                        "iCloud sync",
                        "keepsake does not currently sync your data anywhere; it stays on your device. If we ever add an optional iCloud sync feature, it would be off by default, would use your own private iCloud account (Apple's end-to-end encrypted CloudKit), and still would not send your data to any server of ours. Until you explicitly turn such a feature on, your data stays on this device."
                    )
                    section(
                        "Children's privacy",
                        "keepsake does not collect personal information from anyone, including children. No data is transmitted to us regardless of the user's age."
                    )
                    section(
                        "Changes to this policy",
                        "If we change how the app handles your information, we'll update this policy and revise the effective date above. Because the app is local-only, we can't notify you through a server, so please check this page after app updates."
                    )
                    section(
                        "Contact",
                        "Questions about your privacy or this policy? Email us at hello@keepsakejournal.app."
                    )
                }
                .padding(Spacing.lg)
            }
            .background(Color.appBackground)
            .navigationTitle("privacy policy")   // kept for VoiceOver / semantics
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Replace the system-font title with our serif. `.navigationTitle`
                // can't take a custom font, so a `.principal` toolbar item supplies
                // the visible title in PP Kyoto instead.
                ToolbarItem(placement: .principal) {
                    Text("privacy policy")
                        .font(.kyoto(size: 17))
                        .foregroundStyle(Color.appPrimary)
                }
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
