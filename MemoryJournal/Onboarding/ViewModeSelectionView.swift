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

import SwiftUI

struct ViewModeSelectionView: View {
    var onContinue: () -> Void

    // `@AppStorage` reads/writes a value in UserDefaults AND re-renders the view
    // when it changes — a property wrapper that ties a view to a stored setting.
    // We write to it on Continue. Default `.fiveMonths` matches the Figma, which
    // shows the Five-Month card pre-selected.
    @AppStorage(PreferenceKey.lookbackMode) private var savedMode: LookbackMode = .fiveMonths

    // The live selection while on this screen (committed to `savedMode` on Continue).
    @State private var selection: LookbackMode = .fiveMonths

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content, so it survives large text sizes / small screens.
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    Text("keep your cherished memories")
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.top, Spacing.xxl)

                    VStack(spacing: Spacing.md) {
                        Text("Memory Journal encourages you to revisit and reflect on memories.")
                        Text("Select how far back you want to go. You can change this anytime in Settings.")
                    }
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
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }

            // Continue is pinned below the scroll area so it's always reachable.
            AppButton(title: "Continue") {
                savedMode = selection          // persist the choice
                onContinue()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { selection = savedMode }    // start on whatever's already stored
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
