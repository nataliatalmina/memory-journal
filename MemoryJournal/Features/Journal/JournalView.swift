//
//  JournalView.swift
//  MemoryJournal
//
//  The Journal (Home) screen. Two states on one screen, driven entirely by real
//  data (not a flag):
//    • EMPTY     — no entries in today's look-back window → invite to create one.
//    • POPULATED — a header; then TODAY's entry (with an "Edit memory" button) if
//                  one exists, otherwise a "Create your memory" button; then a
//                  divider and the same-date look-back list (today's date across
//                  the chosen 5 years / 5 months).
//

import SwiftUI
import SwiftData

struct JournalView: View {
    @AppStorage(PreferenceKey.lookbackMode) private var lookbackMode: LookbackMode = .fiveMonths

    // `@Query` fetches from SwiftData AND auto-updates the view whenever the store
    // changes — so a newly saved entry appears here immediately.
    @Query(sort: \Entry.date, order: .reverse) private var allEntries: [Entry]

    // What the composer should present, if anything. Driving the sheet from an
    // `Identifiable` item — rather than a Bool plus a separate `Entry?` — is what
    // fixes the "Edit opens a blank composer" bug: with the split state the sheet
    // could be built before the entry was applied. With `item`, the presentation
    // and its content always move together.
    @State private var composerMode: ComposerMode?
    #if DEBUG
    @State private var showDebugDetail = false   // screenshot hook for the detail view
    #endif

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var targetDates: Set<Date> {
        Set(DateLookup().targetDates(matching: today,
                                     mode: lookbackMode.lookupMode,
                                     count: LookbackMode.count))
    }

    /// Past entries on the matching date (excludes today — today's entry has its
    /// own spot in the header). Newest-first via the `@Query` sort.
    private var lookbackEntries: [Entry] {
        let targets = targetDates
        return allEntries.filter { targets.contains($0.date) && $0.date != today }
    }

    private var todayEntry: Entry? {
        allEntries.first { $0.date == today }
    }

    private var isEmpty: Bool { todayEntry == nil && lookbackEntries.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if isEmpty {
                    EmptyHomeView(today: today, onCreate: openCreate)
                } else {
                    populatedHome
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // we draw our own header
            #if DEBUG
            .navigationDestination(isPresented: $showDebugDetail) {
                if let entry = lookbackEntries.first {
                    EntryDetailView(entry: entry)
                }
            }
            .onAppear {
                // Testing hook: `-openComposer` auto-opens the composer (edit if
                // today's entry exists, otherwise create) so it can be screenshotted.
                if CommandLine.arguments.contains("-openComposer"), composerMode == nil {
                    // Small delay so @Query has populated `todayEntry` first.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        if let todayEntry { openEdit(todayEntry) } else { openCreate() }
                    }
                }
                // Testing hook: `-openDetail` pushes the first look-back entry's read view.
                if CommandLine.arguments.contains("-openDetail") {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        showDebugDetail = true
                    }
                }
            }
            #endif
        }
        .sheet(item: $composerMode) { mode in
            composerSheet(for: mode)
                .presentationBackground(Color.appSurface)
        }
    }

    /// Builds the composer for the requested mode. Create and edit share one
    /// screen; edit passes the existing entry so its title/body/media load.
    @ViewBuilder
    private func composerSheet(for mode: ComposerMode) -> some View {
        switch mode {
        case .create:
            ComposerView(date: today, existingEntry: nil)
        case .edit(let entry):
            ComposerView(date: today, existingEntry: entry)
        }
    }

    private var populatedHome: some View {
        ScrollView {
            VStack(spacing: 0) {
                HomeHeader(today: today)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.lg)

                // Today's entry sits up top (per design + owner's choice). If none
                // exists yet, show the create call-to-action instead.
                if let todayEntry {
                    TodayEntryBlock(entry: todayEntry) { openEdit(todayEntry) }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                } else {
                    AppButton(title: "Create your memory", action: openCreate)
                        .frame(maxWidth: 300)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                }

                ForEach(lookbackEntries) { entry in
                    RowDivider()
                    NavigationLink {
                        EntryDetailView(entry: entry)
                    } label: {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
    }

    private func openCreate() { composerMode = .create }
    private func openEdit(_ entry: Entry) { composerMode = .edit(entry) }

    /// Drives the composer sheet. An `Identifiable` item (not a Bool + optional
    /// Entry) keeps the sheet's identity and its content in lock-step.
    private enum ComposerMode: Identifiable {
        case create
        case edit(Entry)

        var id: String {
            switch self {
            case .create:          "create"
            case .edit(let entry): entry.id.uuidString
            }
        }
    }
}

/// Book logo, "memory journal", today's date. (The action button lives below it,
/// chosen by the parent based on whether today's entry exists.)
private struct HomeHeader: View {
    let today: Date

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // The custom hand-drawn book logo (static), from the asset catalog.
            // `.resizable().scaledToFit()` lets it scale to our width while keeping
            // its real aspect ratio; `accessibilityHidden` because the "memory
            // journal" wordmark right below already conveys it to VoiceOver.
            Image("Home")
                .resizable()
                .scaledToFit()
                .frame(width: 92)
                .accessibilityHidden(true)

            Text("memory journal")
                .font(.kyoto(size: 32))
                .foregroundStyle(Color.appPrimary)

            Text(today.journalHeading())
                .font(.kyoto(size: 20))
                .foregroundStyle(Color.appBodyText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Today's entry shown in the header area. Tapping the content opens the same
/// read-only detail view the look-back rows use (so a long entry can be read in
/// full without entering edit mode); the separate "Edit memory" button is the
/// explicit way to edit. The voice-note play button inside stays independently
/// tappable — the same nesting the look-back rows already rely on.
private struct TodayEntryBlock: View {
    let entry: Entry
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            NavigationLink {
                EntryDetailView(entry: entry)
            } label: {
                EntryContent(entry: entry)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            AppButton(title: "Edit memory", action: onEdit)
                .frame(maxWidth: 300)
        }
    }
}

/// Empty state: centred logo, wordmark, date, the "no entries yet" copy, and the
/// Create button.
private struct EmptyHomeView: View {
    let today: Date
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image("Home")
                .resizable()
                .scaledToFit()
                .frame(width: 110)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("memory journal")
                    .font(.kyoto(size: 32))
                    .foregroundStyle(Color.appPrimary)
                Text(today.journalHeading())
                    .font(.kyoto(size: 20))
                    .foregroundStyle(Color.appBodyText)
            }

            VStack(spacing: Spacing.xs) {
                Text("You haven't made any entries yet.")
                Text("Get started by capturing your first memory.")
            }
            .font(.kyoto(size: 16))
            .foregroundStyle(Color.appBodyText)
            .padding(.top, Spacing.md)

            AppButton(title: "Create your memory", action: onCreate)
                .frame(maxWidth: 300)
                .padding(.top, Spacing.md)

            Spacer()
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.lg)
    }
}

/// The thin teal rule between rows.
private struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.appPrimary.opacity(0.35))
            .frame(height: 0.5)
    }
}

#Preview {
    JournalView()
        .modelContainer(for: Entry.self, inMemory: true)
}
