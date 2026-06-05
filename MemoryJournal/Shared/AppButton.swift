//
//  AppButton.swift
//  MemoryJournal
//
//  The app's reusable call-to-action button: full-width, rounded, with an
//  italic-serif label. Reused everywhere the designs show a main action
//  ("Create your memory", "Continue", "Get started with prompt", …).
//
//  Named `AppButton` (not `PrimaryButton`) because the same component carries
//  both the primary and secondary looks via the `style` parameter — that keeps
//  one source of truth for the shape, padding, and font.
//

import SwiftUI

struct AppButton: View {
    /// The two visual variants from the designs.
    enum Style {
        case primary    // deep teal — main action
        case secondary  // sage-teal — secondary action (e.g. "Enable Photo Library")

        /// Fill colour for each variant. A `switch` used as an expression:
        /// it evaluates to the matching colour.
        var fill: Color {
            switch self {
            case .primary:   Color.appPrimary
            case .secondary: Color.appSecondary
            }
        }
    }

    let title: String
    var style: Style = .primary
    /// Label point size. Default 20 matches the Figma "Continue" call-to-action.
    var labelSize: CGFloat = 20
    /// What to run when tapped. `() -> Void` is the type of a closure that takes
    /// no arguments and returns nothing — i.e. a plain "do this" block.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                // Italic serif button label (PP Kyoto MediumItalic), per CLAUDE.md.
                .font(.kyotoItalic(size: labelSize))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)        // stretch to the full available width
                .padding(.vertical, Spacing.md)    // comfortable tap height
        }
        .background(style.fill)
        .clipShape(.rect(cornerRadius: CornerRadius.button))
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        AppButton(title: "Create your memory") { }
        AppButton(title: "Enable Photo Library", style: .secondary) { }
    }
    .padding(Spacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.appBackground)
}
