//
//  EntryRow.swift
//  MemoryJournal
//
//  One row in the home look-back list: a date heading, the title (if any), an
//  italic truncated excerpt of the body, and — depending on the entry's media —
//  a right-aligned photo thumbnail and/or an inline voice-note player.
//

import SwiftUI

/// A full look-back row: the date heading plus the shared entry content.
struct EntryRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Date heading, e.g. "15 august 2025" (upright serif, teal).
            Text(entry.date.journalHeading())
                .font(.kyoto(size: 24))
                .foregroundStyle(Color.appPrimary)

            EntryContent(entry: entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.lg)
        .contentShape(Rectangle())   // make the whole row tappable, not just the text
    }
}

/// The reusable inner content of an entry: optional title, an italic truncated
/// body excerpt, and any media (photo thumbnail beside the text, voice player
/// below). Used by the look-back rows AND by today's-entry block in the header.
struct EntryContent: View {
    let entry: Entry
    var excerptLineLimit: Int = 6

    private var hasPhoto: Bool { !entry.photoFilenames.isEmpty }
    private var hasAudio: Bool { entry.voiceNoteFilename != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let title = entry.title, !title.isEmpty {
                // Bold (vs the Medium body) so the title reads as a clear second
                // level under the teal date heading.
                Text(title)
                    .font(.kyotoBold(size: 17))
                    .foregroundStyle(Color.appBodyText)
            }

            // The design shows photo BESIDE the text, and a voice note BELOW the
            // text. We support both at once if an entry has both.
            if hasPhoto {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    excerpt(lineLimit: excerptLineLimit)
                    PhotoThumbnail(filename: entry.photoFilenames[0])
                }
            } else {
                excerpt(lineLimit: hasAudio ? 3 : excerptLineLimit)
            }

            if let voiceNote = entry.voiceNoteFilename {
                VoiceNotePlayerBar(filename: voiceNote)
            }
        }
    }

    /// Italic, truncated body excerpt in PP Kyoto Medium Italic (`.kyotoItalic`).
    /// The Figma uses Regular Italic; Medium Italic is very close and owner-confirmed
    /// to keep (no need to register the lighter Regular weight).
    private func excerpt(lineLimit: Int) -> some View {
        Text(entry.body)
            .font(.kyotoItalic(size: 16))
            .foregroundStyle(Color.appBodyText)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Right-aligned thumbnail (first photo). Renders the real image from the app
/// container, or a neutral placeholder when the file isn't there yet (e.g. the
/// seeded voice/photo samples before Part C writes real photos).
struct PhotoThumbnail: View {
    let filename: String

    var body: some View {
        Group {
            if let image = MediaStore.loadPhoto(filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.appSecondary.opacity(0.25)
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(Color.appSecondary)
                }
            }
        }
        .frame(width: 100, height: 150)
        .clipShape(.rect(cornerRadius: 6))   // small radius (design is square; rounded reads friendlier)
    }
}

/// The inline teal voice-note player bar: play/pause + a (representative)
/// waveform whose fill tracks playback. Playback runs through the shared
/// `VoicePlayer`, so only one note plays at a time across the app.
/// Pass `onRemove` in the composer to show a trailing ✕.
struct VoiceNotePlayerBar: View {
    let filename: String
    var onRemove: (() -> Void)? = nil

    @Environment(VoicePlayer.self) private var player

    private var isPlaying: Bool { player.isPlaying(filename) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Button { player.toggle(filename) } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isPlaying ? "Pause voice note" : "Play voice note")

            WaveformView(progress: isPlaying ? player.progress : 0)
                .frame(height: 15)
                .frame(maxWidth: .infinity)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Remove voice note")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(Color.appPrimary)
        .clipShape(.rect(cornerRadius: CornerRadius.button))
    }
}
