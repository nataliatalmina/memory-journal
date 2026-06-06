//
//  ComposerView.swift
//  MemoryJournal
//
//  The composer for TODAY's entry. Presented as a sheet from Home. Works in two
//  modes from one screen:
//    • create — `existingEntry == nil`: a fresh entry for `date`.
//    • edit   — `existingEntry != nil`: load that entry's title/body and update it.
//
//  Save rule (confirmed with owner): an entry needs non-whitespace BODY text.
//  Title is optional. An empty body can't be saved.
//
//  Media toolbar (camera / photo / mic) is shown here; the buttons are wired up
//  in Part C (photos) and Part D (voice). For now they're visual placeholders.
//

import SwiftUI
import SwiftData

struct ComposerView: View {
    // `modelContext` is SwiftData's "scratchpad" for this view: we insert a new
    // entry (or mutate an existing one) and call `save()` to write to disk.
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let date: Date
    var existingEntry: Entry?

    // `@State` holds the editable text. `TextField`/`TextEditor` bind to these
    // with `$title` / `$bodyText` — a two-way binding, so typing updates the
    // state and the state updates the field.
    @State private var title: String = ""
    @State private var bodyText: String = ""
    // `@FocusState` lets us know / control whether the body editor has the keyboard.
    @FocusState private var bodyFocused: Bool

    /// Can we save? Uses the same rule as `save()` — body must have real text.
    private var canSave: Bool {
        Entry.cleanedInput(title: title, body: bodyText) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(date.journalHeading())
                .font(.kyoto(size: 20))
                .foregroundStyle(Color.appBodyText)

            titleField

            bodyEditor   // expands to fill the space between title and toolbar

            mediaToolbar

            AppButton(title: "Save your memory", action: save)
                .opacity(canSave ? 1 : 0.45)
                .disabled(!canSave)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appSurface)
        .onAppear {
            // In edit mode, preload the entry's current text.
            if let entry = existingEntry {
                title = entry.title ?? ""
                bodyText = entry.body
            }
            #if DEBUG
            // Testing hook: `-focusBody` raises the keyboard so we can verify the
            // toolbar + Save stay reachable above it.
            if CommandLine.arguments.contains("-focusBody") {
                Task { @MainActor in bodyFocused = true }
            }
            #endif
        }
    }

    // MARK: - Title (single line, custom-coloured placeholder)

    private var titleField: some View {
        TextField("", text: $title)
            .font(.kyoto(size: 32))
            .foregroundStyle(Color.appPrimary)
            .tint(Color.appPrimary)
            .overlay(alignment: .leading) {
                if title.isEmpty {
                    Text("Title your entry")
                        .font(.kyoto(size: 32))
                        .foregroundStyle(Color.appPrimary.opacity(0.6))
                        .allowsHitTesting(false)   // taps pass through to the field
                }
            }
    }

    // MARK: - Body (multi-line, grows, custom placeholder)

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            // TextEditor has no placeholder, so we overlay one when empty.
            if bodyText.isEmpty {
                Text("Write about something you want to remember....")
                    .font(.kyotoItalic(size: 18))
                    .foregroundStyle(Color.appBodyText.opacity(0.8))
                    .padding(.top, 8)
                    .padding(.leading, 5)   // line up with TextEditor's text inset
                    .allowsHitTesting(false)
            }

            TextEditor(text: $bodyText)
                .font(.kyoto(size: 18))
                .foregroundStyle(Color.appBodyText)
                .tint(Color.appPrimary)
                .scrollContentBackground(.hidden)   // hide TextEditor's own white bg
                .focused($bodyFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Media toolbar (wired up in Parts C & D)

    private var mediaToolbar: some View {
        // Each icon keeps a 44×44pt tap target (Apple HIG minimum), and the
        // targets sit ADJACENT (spacing 0) so the glyphs group ~20pt apart —
        // the tight, familiar density used in Messages/Mail input bars.
        HStack(spacing: 0) {
            Spacer()
            toolbarIcon("camera")     { /* TODO(Part C): capture a photo */ }
            toolbarIcon("photo")      { /* TODO(Part C): pick from library */ }
            toolbarIcon("mic")        { /* TODO(Part D): record a voice note */ }
        }
    }

    private func toolbarIcon(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 44, height: 44)   // HIG minimum tap target
        }
    }

    // MARK: - Save

    private func save() {
        // One rule, shared with `canSave`. nil → nothing to save.
        guard let cleaned = Entry.cleanedInput(title: title, body: bodyText) else { return }

        if let entry = existingEntry {
            // Edit: mutate the managed object and stamp the modified time.
            entry.title = cleaned.title
            entry.body = cleaned.body
            entry.modifiedAt = .now
        } else {
            // Create: insert a new entry for today (Entry normalises the date to
            // start-of-day itself).
            context.insert(Entry(date: date, title: cleaned.title, body: cleaned.body))
        }

        try? context.save()
        dismiss()   // back to Home, which auto-updates via @Query
    }
}

#Preview {
    ComposerView(date: .now)
        .modelContainer(for: Entry.self, inMemory: true)
}
