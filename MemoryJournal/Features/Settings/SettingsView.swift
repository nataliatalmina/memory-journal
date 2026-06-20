//
//  SettingsView.swift
//  MemoryJournal
//
//  The Settings tab (Phase 6, the final screen). Grouped settings in the app's own
//  editorial style (off-white rounded cards on the pale background, PP Kyoto,
//  lowercase section titles) rather than stock iOS `Form`, so it matches the rest
//  of the app. Sections: look-back · permissions · privacy & security · data · about.
//
//  Honesty rule (CLAUDE.md): everything here reflects what the code actually does.
//  Permission rows show real authorization status; nothing implies off-device
//  storage. The look-back control reads/writes the SAME persisted setting that
//  onboarding wrote and the Home query reads — changing it here changes Home live.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    // THE shared source of truth for the look-back window. This is the exact same
    // `@AppStorage` key onboarding wrote (`ViewModeSelectionView`) and Home reads
    // (`JournalView`). Writing it here updates Home immediately — no second copy.
    @AppStorage(PreferenceKey.lookbackMode) private var lookbackMode: LookbackMode = .fiveMonths
    @AppStorage(PreferenceKey.appLockEnabled) private var appLockEnabled = false

    // SwiftData context — used by "Delete all data" to wipe every entry.
    @Environment(\.modelContext) private var context

    // Current permission statuses, filled on appear and after returning from the
    // Settings app.
    @State private var statuses: [MediaCapability: PermissionStatus] = [:]
    // What kind of auth this device can do (decides whether App Lock is offered).
    @State private var lockAvailability: BiometricLock.Availability = .unavailable

    @State private var showPrivacyPolicy = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Text("settings")
                        .font(.kyoto(size: 28))
                        .foregroundStyle(Color.appPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.xl)

                    lookBackSection
                    permissionsSection
                    privacySecuritySection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()   // the SAME screen onboarding links to (reused)
        }
        .alert("Delete all data?", isPresented: $showDeleteConfirm) {
            Button("Delete Everything", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every journal entry and all photos and voice notes from this device. This cannot be undone.")
        }
        .onAppear(perform: refresh)
    }

    // MARK: - look-back

    private var lookBackSection: some View {
        SettingsSection(title: "look-back") {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("How far back the Home screen looks — the same date across five months or five years.")
                    .font(.kyoto(size: 14))
                    .foregroundStyle(Color.appBodyText)
                    .fixedSize(horizontal: false, vertical: true)

                LookbackSegmented(mode: $lookbackMode)

                // Mirror onboarding: show the periods this choice will surface.
                ChipRow(labels: lookbackMode.exampleChips())
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - permissions

    private var permissionsSection: some View {
        SettingsSection(title: "permissions") {
            VStack(spacing: 0) {
                ForEach(Array(MediaCapability.allCases.enumerated()), id: \.element) { index, capability in
                    if index > 0 { RowSeparator() }
                    PermissionRow(
                        capability: capability,
                        status: statuses[capability] ?? .notDetermined,
                        onRequest: { request(capability) }
                    )
                }
            }
        }
    }

    // MARK: - privacy & security

    private var privacySecuritySection: some View {
        SettingsSection(title: "privacy & security") {
            VStack(spacing: 0) {
                AppLockRow(
                    isOn: $appLockEnabled,
                    availability: lockAvailability
                )
                RowSeparator()
                DisclosureRow(label: "Privacy Policy") { showPrivacyPolicy = true }
            }
        }
    }

    // MARK: - data

    private var dataSection: some View {
        SettingsSection(title: "data") {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Text("Delete All Data")
                        .font(.kyoto(size: 16))
                        .foregroundStyle(Color.appDestructive)
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appDestructive)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Permanently deletes every entry and all media. Cannot be undone.")
        }
    }

    // MARK: - about

    private var aboutSection: some View {
        SettingsSection(title: "about") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("memory journal")
                    .font(.kyoto(size: 22))
                    .foregroundStyle(Color.appPrimary)

                Text(versionString)
                    .font(.kyoto(size: 14))
                    .foregroundStyle(Color.appBodyText.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Our memories make us human.")
                    Text("Don't let them fade away.")
                }
                .font(.kyotoItalic(size: 15))
                .foregroundStyle(Color.appBodyText)
                .padding(.top, Spacing.xs)

                Text("Local-only. Your memories stay on this device.")
                    .font(.kyoto(size: 13))
                    .foregroundStyle(Color.appBodyText.opacity(0.7))
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
    }

    /// "Version 1.0 (1)" — read from the bundle so it always matches the build.
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    // MARK: - Actions

    private func refresh() {
        for capability in MediaCapability.allCases {
            statuses[capability] = MediaPermissions.status(of: capability)
        }
        lockAvailability = BiometricLock.availability()
    }

    private func request(_ capability: MediaCapability) {
        Task {
            statuses[capability] = await MediaPermissions.request(capability)
        }
    }

    private func deleteAllData() {
        // Remove every entry from the database, then every media file on disk.
        try? context.delete(model: Entry.self)
        try? context.save()
        MediaStore.deleteAllMedia()
    }
}

// MARK: - Reusable building blocks

/// A titled group: a lowercase section title above an off-white rounded card.
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.kyoto(size: 14))
                .foregroundStyle(Color.appBodyText.opacity(0.55))
                .padding(.leading, Spacing.xs)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface, in: .rect(cornerRadius: CornerRadius.card))
        }
    }
}

/// A hairline divider between rows in a card (inset from the leading edge, like
/// iOS grouped lists).
private struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.appBodyText.opacity(0.12))
            .frame(height: 0.5)
            .padding(.leading, Spacing.md)
    }
}

/// A tappable row with a label and a trailing chevron (used for Privacy Policy).
private struct DisclosureRow: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appBodyText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appBodyText.opacity(0.35))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A two-segment look-back control. Selected segment fills teal; the other shows
/// teal text on the pale-teal track (the same high-contrast treatment as the
/// prompt cards).
private struct LookbackSegmented: View {
    @Binding var mode: LookbackMode

    var body: some View {
        HStack(spacing: 0) {
            segment(.fiveMonths, "Five-Month")
            segment(.fiveYears, "Five-Year")
        }
        .padding(4)
        .background(Color.appPrimary.opacity(0.08), in: .rect(cornerRadius: CornerRadius.button))
    }

    private func segment(_ value: LookbackMode, _ label: String) -> some View {
        let isSelected = mode == value
        return Button {
            mode = value
        } label: {
            Text(label)
                .font(.kyoto(size: 16))
                .foregroundStyle(isSelected ? Color.white : Color.appPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.appPrimary : Color.clear,
                            in: .rect(cornerRadius: CornerRadius.button - 4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A wrapping-free row of small period chips (years or month names), mirroring the
/// onboarding view-mode cards so the choice feels consistent.
private struct ChipRow: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.kyoto(size: 11))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.appPrimary.opacity(0.08))
                    .clipShape(.rect(cornerRadius: CornerRadius.chip))
            }
        }
    }
}

/// One permission row: the capability name and its real status. Tapping a
/// not-yet-asked permission shows the system prompt; tapping an already-decided
/// one deep-links to the app's page in the Settings app (iOS only prompts once,
/// so that's the only way to change it afterwards).
private struct PermissionRow: View {
    let capability: MediaCapability
    let status: PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        Button(action: act) {
            HStack {
                Text(name)
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appBodyText)
                Spacer()
                Text(valueText)
                    .font(.kyoto(size: 15))
                    .foregroundStyle(valueColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appBodyText.opacity(0.35))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(valueText)")
        .accessibilityHint(status == .notDetermined ? "Asks for permission" : "Opens Settings")
    }

    private func act() {
        switch status {
        case .notDetermined: onRequest()
        case .granted, .denied: openSettings()
        }
    }

    private var name: String {
        switch capability {
        case .camera:       "Camera"
        case .photoLibrary: "Photo Library"
        case .microphone:   "Microphone"
        }
    }

    /// Honest, plain wording for each state.
    private var valueText: String {
        switch status {
        case .granted:       "On"
        case .denied:        "Off"
        case .notDetermined: "Enable"
        }
    }

    private var valueColor: Color {
        switch status {
        case .granted:       Color.appPrimary
        case .notDetermined: Color.appPrimary
        case .denied:        Color.appBodyText.opacity(0.6)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

/// The App Lock toggle row. Adapts its subtitle to what the device can do, and
/// disables itself entirely when there's no biometrics or passcode set up.
private struct AppLockRow: View {
    @Binding var isOn: Bool
    let availability: BiometricLock.Availability

    private var isAvailable: Bool { availability != .unavailable }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("App Lock")
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appBodyText)
                Text(subtitle)
                    .font(.kyoto(size: 13))
                    .foregroundStyle(Color.appBodyText.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.appPrimary)
                .disabled(!isAvailable)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("App Lock")
        .accessibilityHint(subtitle)
    }

    private var subtitle: String {
        switch availability {
        case .biometric, .passcodeOnly:
            return "Require \(BiometricLock.methodName()) to open Memory Journal."
        case .unavailable:
            return "Set up Face ID, Touch ID, or a device passcode to use App Lock."
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Entry.self, inMemory: true)
}
