//
//  LookbackPhotoRow.swift
//  MemoryJournal
//
//  A look-back row that holds a PHOTO instead of an entry — shown where the user
//  wrote nothing on that date but their camera was there (see
//  docs/photo-lookback-plan.md).
//
//  It deliberately shares `EntryRow`'s shape: the same teal date heading, the
//  same padding, the same dividers around it, so the list reads as one sequence
//  of memories rather than two interleaved features. What it does NOT do is
//  pretend to be an entry — the small "from your photos" line says plainly where
//  it came from, so nobody mistakes it for something they wrote.
//

import SwiftUI

struct LookbackPhotoRow: View {
    let date: Date
    let candidate: PhotoCandidate
    /// Open the full-screen viewer.
    let onOpen: () -> Void
    /// "Don't show this photo" — hides it for good.
    let onDismiss: () -> Void

    /// Roughly 4:3, which suits most camera photos without letterboxing. The
    /// frame is fixed so the row doesn't jump about as the image loads.
    private static let imageHeight: CGFloat = 220

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Same heading style as EntryRow, so the dates line up down
                    // the screen whatever each slot turned out to hold.
                    Text(date.journalHeading())
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)

                    Text("from your photos")
                        .font(.kyotoItalic(size: 14))
                        .foregroundStyle(Color.appBodyText.opacity(0.7))
                }

                GeometryReader { proxy in
                    PhotoLibraryImage(
                        localIdentifier: candidate.localIdentifier,
                        displaySize: CGSize(width: proxy.size.width, height: Self.imageHeight)
                    )
                    .frame(width: proxy.size.width, height: Self.imageHeight)
                    .clipped()
                }
                .frame(height: Self.imageHeight)
                .clipShape(.rect(cornerRadius: CornerRadius.card))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xl)
            .padding(.horizontal, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A context menu rather than a visible ✕: a permanent close button on a
        // memory is both visually noisy and easy to hit by accident, and this
        // action can't be undone from here.
        .contextMenu {
            Button("Don't show this photo", systemImage: "eye.slash", action: onDismiss)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo from \(date.journalHeading())")
        .accessibilityHint("Opens the photo. Touch and hold to stop showing it.")
        .accessibilityAddTraits(.isButton)
        // VoiceOver can't reach a context menu by touch-and-hold, so the dismiss
        // action is also offered as a rotor action.
        .accessibilityAction(named: "Don't show this photo", onDismiss)
    }
}

/// Shown in the FIRST empty look-back slot when the user has switched photo
/// look-back on but iOS hasn't been asked for access yet. Tapping it raises the
/// system prompt.
///
/// This card is the ONLY thing in the app that triggers the photo-library prompt,
/// and that is a deliberate App Review decision, not a UI preference: the request
/// happens at the point of use, in the exact place the photo would appear, with
/// no screen in front of it explaining or arguing for it. See CLAUDE.md →
/// "Permission requests" before moving or copying this.
///
/// Only one is ever shown, in the topmost gap. Repeating it down every empty slot
/// would turn a quiet offer into nagging.
struct LookbackPhotoOfferRow: View {
    let date: Date
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(date.journalHeading())
                    .font(.kyoto(size: 24))
                    .foregroundStyle(Color.appPrimary)

                // Neutral, factual wording. No "Allow", "Enable" or "Turn on" —
                // persuasive language in front of a system prompt is what got
                // build 1.0 (3) rejected.
                //
                // It DOES forewarn the system dialog, though. Someone who switched
                // this on in onboarding has already said yes once; without that
                // clause the prompt arrives as a surprise, and the card reads as
                // the app asking a question it was already answered. Saying what
                // the tap does is description, not persuasion.
                Text("Nothing written on this date. Tap to look for a photo — keepsake will ask to read your photo library.")
                    .font(.kyotoItalic(size: 16))
                    .foregroundStyle(Color.appBodyText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xl)
            .padding(.horizontal, Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Asks for permission to read photos taken on this date")
    }
}

/// Shown in place of the offer card when the user granted "Selected Photos".
///
/// Limited access is the state most likely to look like a broken feature: keepsake
/// can only search the handful of photos the user picked, finds nothing on almost
/// every date, and renders an empty screen indistinguishable from "you took no
/// photos that day". Saying so is the honest thing to do.
struct LookbackPhotoLimitedRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("keepsake can only see the photos you selected, so it may not find one for this date.")
                .font(.kyotoItalic(size: 15))
                .foregroundStyle(Color.appBodyText.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Settings")
    }
}
