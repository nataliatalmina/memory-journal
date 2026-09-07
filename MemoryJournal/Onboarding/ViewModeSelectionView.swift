//
//  ViewModeSelectionView.swift
//  MemoryJournal
//
//  Onboarding screen 2 — "keep your cherished memories". The user picks how far
//  back the app looks (five months or five years). Exactly one card is selected
//  at a time: the selected card is deep teal, the other muted sage. On Continue
//  we PERSIST the choice into `LookbackMode` (UserDefaults via @AppStorage) —
//  the same setting the journal query reads and Settings will later edit.
//
//  IT ALSO CARRIES THE PHOTO LOOK-BACK TOGGLE, and there is a rule about that.
//  This screen must NEVER call a Photos API or request any permission. It stores
//  an intent — "I'd like photos in my empty look-back slots" — in exactly the way
//  it already stores five-months-vs-five-years. The system prompt is raised much
//  later, and only when the user taps the card in the empty slot itself on the
//  Journal screen (`LookbackPhotoOfferRow`).
//
//  That separation is deliberate: a screen that explains a permission and then
//  triggers it violates App Store guideline 5.1.1(iv), which is what got build
//  1.0 (3) rejected. Hence also no persuasive vocabulary anywhere here — no
//  "Allow", "Enable", "Turn on", "Grant", or "Access". See CLAUDE.md →
//  "Permission requests" before changing a word of this.
//

import SwiftUI

struct ViewModeSelectionView: View {
    var onContinue: () -> Void

    // `@AppStorage` reads/writes a value in UserDefaults AND re-renders the view
    // when it changes — a property wrapper that ties a view to a stored setting.
    // We write to it on Continue. Default `.fiveMonths` matches the Figma, which
    // shows the Five-Month card pre-selected.
    @AppStorage(PreferenceKey.lookbackMode) private var savedMode: LookbackMode = .fiveMonths
    @AppStorage(PreferenceKey.photoLookbackEnabled) private var savedPhotoLookback = false

    // The live selection while on this screen (committed to `savedMode` on Continue).
    @State private var selection: LookbackMode = .fiveMonths
    // Likewise for the photo toggle. Off by default: this is opt-in, and a
    // pre-ticked box isn't a choice.
    @State private var wantsPhotos = false

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content, so it survives large text sizes / small screens.
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Text("keep your cherished memories")
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.top, Spacing.xl)

                    // One line, not two. "keepsake encourages you to revisit and
                    // reflect on memories" said what the heading and the splash
                    // tagline already say, and the two paragraphs cost enough
                    // height to push the photo card below the fold.
                    Text("Select how far back you want to go. You can change this anytime in Settings.")
                        .font(.kyoto(size: 16))
                        .foregroundStyle(Color.appBodyText)

                    VStack(spacing: Spacing.lg) {
                        ForEach(LookbackMode.allCases) { mode in
                            LookbackOptionCard(
                                mode: mode,
                                isSelected: selection == mode,
                                onTap: { selection = mode }
                            )
                        }
                    }
                    .padding(.top, Spacing.md)

                    PhotoLookbackOptIn(isOn: $wantsPhotos)
                        .padding(.top, Spacing.sm)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }

            // Continue is pinned below the scroll area so it's always reachable.
            AppButton(title: "Continue") {
                savedMode = selection                  // persist the choices
                savedPhotoLookback = wantsPhotos
                onContinue()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {                            // start on whatever's already stored
            selection = savedMode
            wantsPhotos = savedPhotoLookback
        }
    }
}

/// The photo look-back opt-in: a plain preference, on a screen of preferences.
///
/// Deliberately quieter than the two look-back cards above it — an off-white card
/// rather than a filled teal one — because it's a secondary choice, and because
/// something that looks like a call to action in front of a later permission
/// prompt is exactly what we must not build (see the file header).
private struct PhotoLookbackOptIn: View {
    @Binding var isOn: Bool

    // Deliberately says "without journal entries" rather than naming a period:
    // this screen is where the user picks months or years, so wording tied to
    // either one would be wrong for half of them. "Entries" rather than "you
    // didn't write" because an entry can be a photo or a voice note alone.
    private let explanation = "On days without journal entries, keepsake can show you a photo you took instead. Nothing is copied or stored."

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("photos from this date")
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appPrimary)

                Text(explanation)
                    .font(.kyoto(size: 13))
                    .foregroundStyle(Color.appBodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.appPrimary)
        }
        // Stretch to the full available width, the same way `LookbackOptionCard`
        // does. Without this the HStack sizes to its content and the card sits
        // visibly narrower than the two option cards above it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.appSurface, in: .rect(cornerRadius: CornerRadius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Photos from this date")
        .accessibilityHint(explanation)
    }
}

/// One selectable card (Five-Month or Five-Year): heading, description, and a
/// row of example "period" chips. Filled teal when selected, sage when not.
private struct LookbackOptionCard: View {
    let mode: LookbackMode
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(mode.title)
                    .font(.kyoto(size: 16))
                    .foregroundStyle(.white)

                Text(mode.detail)
                    .font(.kyoto(size: 13))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true) // allow wrapping

                // Period chips (e.g. months or years). Wrap to a new line if the
                // text size grows, instead of overflowing.
                ChipRow(labels: mode.exampleChips())
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? Color.appPrimary : Color.appSecondary)
            .clipShape(.rect(cornerRadius: CornerRadius.card))
        }
        .buttonStyle(.plain)
        // Accessibility: expose the card as a selectable option to VoiceOver.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A wrapping row of small pill labels.
private struct ChipRow: View {
    let labels: [String]

    var body: some View {
        // Chips are short (5 month names or years), so a single row is enough to
        // match the design without a custom wrapping layout.
        HStack(spacing: Spacing.xs) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.kyoto(size: 11))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.appBackground)
                    .clipShape(.rect(cornerRadius: CornerRadius.chip))
            }
        }
    }
}

#Preview {
    ViewModeSelectionView(onContinue: {})
        .background(Color.appBackground)
}
