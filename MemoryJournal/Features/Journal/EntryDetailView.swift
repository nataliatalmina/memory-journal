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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                EntryReadContent(entry: entry)

                // A deliberate, understated way to remove a past memory — gated by
                // a confirmation. On delete we pop back (Home) / dismiss the sheet
                // (Prompts); the @Query then drops it from the look-back list.
                HStack {
                    Spacer()
                    DeleteMemoryButton {
                        entry.deleteWithMedia(in: context)
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.top, Spacing.lg)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A calm, deliberate "delete this memory" affordance — understated red text + a
/// trash icon, gated behind a confirmation. Reused by the entry detail view and
/// the composer's edit mode so deletion looks and reads the same everywhere.
struct DeleteMemoryButton: View {
    let onConfirm: () -> Void
    @State private var showConfirm = false

    var body: some View {
        Button { showConfirm = true } label: {
            Label("Delete this memory", systemImage: "trash")
                .font(.kyoto(size: 16))
                .foregroundStyle(Color.appDestructive)
        }
        .buttonStyle(.plain)
        .alert("Delete this memory?", isPresented: $showConfirm) {
            Button("Delete", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes this memory, including its photos and voice note, from this device. This can't be undone.")
        }
    }
}

/// The read-only presentation of an entry's content — date heading, optional
/// title, body, photos, and voice player. Extracted (Phase 5) so BOTH the pushed
/// detail screen (Home) and the Calendar screen render an entry **identically**.
///
/// This is deliberately read-only: it has no text fields, no Save button, none of
/// the composer's editing controls. The Calendar never edits, so it reuses this.
struct EntryReadContent: View {
    let entry: Entry

    private var hasTitle: Bool { !(entry.title ?? "").isEmpty }

    var body: some View {
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

            if let voiceNote = entry.voiceNoteFilename {
                VoiceNotePlayerBar(filename: voiceNote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
