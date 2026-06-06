//
//  EntryDetailView.swift
//  MemoryJournal
//
//  Read-only view of a past entry, pushed when a look-back row is tapped. It
//  shows the full body (not truncated) plus any photos and the voice note.
//
//  Design decision (Part A) — see CLAUDE.md / the session notes: tapping a past
//  memory opens this dedicated READ-ONLY view rather than reusing the composer.
//  Reasoning: the composer's job is "write today"; a past memory is something you
//  revisit, so a calm read view keeps those intents separate and the composer
//  simple. If we later want to edit past entries, we can add an Edit affordance
//  here that opens the composer seeded with this entry.
//

import SwiftUI

struct EntryDetailView: View {
    let entry: Entry

    private var hasTitle: Bool { !(entry.title ?? "").isEmpty }

    var body: some View {
        ScrollView {
            // Read view hierarchy (all PP Kyoto Medium so the body shows the entry's
            // own text faithfully). With a title:   date (grey 17) → title (teal 24).
            // Without a title, the date takes the prominent role: date (teal 24).
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(entry.date.journalHeading())
                    .font(.kyoto(size: hasTitle ? 17 : 24))
                    .foregroundStyle(hasTitle ? Color.appBodyText : Color.appPrimary)

                if let title = entry.title, !title.isEmpty {
                    Text(title)
                        .font(.kyoto(size: 24))
                        .foregroundStyle(Color.appPrimary)
                }

                Text(entry.body)
                    .font(.kyoto(size: 16))
                    .foregroundStyle(Color.appBodyText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !entry.photoFilenames.isEmpty {
                    ForEach(entry.photoFilenames, id: \.self) { filename in
                        PhotoView(filename: filename)
                    }
                }

                if entry.voiceNoteFilename != nil {
                    VoiceNotePlayerBar()
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A full-width photo in the detail view (the row uses a small thumbnail instead).
private struct PhotoView: View {
    let filename: String

    var body: some View {
        Group {
            if let image = MediaStore.loadPhoto(filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color.appSecondary.opacity(0.25)
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(Color.appSecondary)
                }
                .frame(height: 200)
            }
        }
        .clipShape(.rect(cornerRadius: CornerRadius.card))
    }
}
