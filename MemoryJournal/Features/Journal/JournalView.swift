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
import UIKit   // UIApplication.openSettingsURLString

struct JournalView: View {
    @AppStorage(PreferenceKey.lookbackMode) private var lookbackMode: LookbackMode = .fiveMonths
    @AppStorage(PreferenceKey.photoLookbackEnabled) private var photoLookbackEnabled = false

    @Environment(\.openURL) private var openURL

    // `@Query` fetches from SwiftData AND auto-updates the view whenever the store
    // changes — so a newly saved entry appears here immediately.
    @Query(sort: \Entry.date, order: .reverse) private var allEntries: [Entry]

    // What the composer should present, if anything. Driving the sheet from an
    // `Identifiable` item — rather than a Bool plus a separate `Entry?` — is what
    // fixes the "Edit opens a blank composer" bug: with the split state the sheet
    // could be built before the entry was applied. With `item`, the presentation
    // and its content always move together.
    @State private var composerMode: ComposerMode?

    // The past entry currently open in the read-only detail SHEET (nil = closed).
    // We present the detail view as a sheet rather than pushing it: a pushed view
    // lives inside the tab's screen, so the custom bottom tab bar (added via
    // `.safeAreaInset` in RootTabView) overlaps its lower content and traps the
    // "Delete this memory" button. A sheet floats above the bar, keeping it reachable.
    @State private var detailEntry: Entry?

    // MARK: Photo look-back state (Phase 7)

    /// The photo chosen for each look-back date that has one. Empty when the
    /// feature is off, unauthorised, or simply found nothing.
    @State private var photos: [Date: PhotoCandidate] = [:]

    /// The live photo-library authorization. Read on appear, updated after the
    /// user answers the system prompt.
    @State private var photoAccess: PermissionStatus = .notDetermined

    /// Bumped when the user dismisses a photo, purely to re-run the lookup so the
    /// slot can refill with a different photo from the same day.
    @State private var dismissalGeneration = 0

    /// The photo open in the full-screen viewer (nil = closed).
    @State private var viewerPhoto: PhotoSelection?

    // Today as a canonical entry date (see Shared/JournalDay.swift). Flips at local
    // midnight, but encoded so it compares exactly against stored entries.
    private var today: Date { .journalToday }

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

    /// The look-back dates in display order — most recent first, today dropped
    /// (today has its own place in the header).
    private var pastTargetDates: [Date] {
        Array(DateLookup().targetDates(matching: today,
                                       mode: lookbackMode.lookupMode,
                                       count: LookbackMode.count).dropFirst())
    }

    /// One entry per look-back date, for O(1) lookup while building the slots.
    /// The app allows only one entry per day, so a collision can't happen; the
    /// `uniquingKeysWith` is just what the initialiser requires.
    private var entriesByDate: [Date: Entry] {
        Dictionary(lookbackEntries.map { ($0.date, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// What actually renders below the header, in order.
    ///
    /// Each past date resolves to exactly one thing: the entry written that day,
    /// or a photo taken that day, or — once, in the topmost gap — an invitation
    /// to turn photos on. A date with none of those contributes nothing, which is
    /// the same silence the screen has always used for a day with no entry.
    private var lookbackSlots: [LookbackSlot] {
        let entries = entriesByDate
        var slots: [LookbackSlot] = []
        var hasShownPrompt = false

        for date in pastTargetDates {
            if let entry = entries[date] {
                slots.append(.entry(entry))
                continue
            }
            if let candidate = photos[date] {
                slots.append(.photo(date: date, candidate: candidate))
                continue
            }

            // An empty slot. Say something about photos only if the user has asked
            // for them and there's something to say — and only once, so an empty
            // week doesn't turn into a column of identical cards.
            guard photoLookbackEnabled, !hasShownPrompt else { continue }
            switch photoAccess {
            case .notDetermined:
                slots.append(.offer(date: date))
                hasShownPrompt = true
            case .limited:
                slots.append(.limitedAccess(date: date))
                hasShownPrompt = true
            case .granted, .denied:
                // Nothing to add: either we searched and found no photo that day,
                // or the user has said no and mustn't be asked again.
                continue
            }
        }
        return slots
    }

    private var todayEntry: Entry? {
        allEntries.first { $0.date == today }
    }

    /// Nothing to show at all — not today's entry, not a past entry, not a photo,
    /// not even an offer of one. Note this counts SLOTS, not entries: a screen
    /// full of photos is not an empty screen.
    private var isEmpty: Bool { todayEntry == nil && lookbackSlots.isEmpty }

    /// True once the user has written ANY entry, anywhere in the journal — not just
    /// inside today's look-back window. The empty state uses this to tell the two
    /// cases apart: a brand-new journal vs. a journal whose entries all sit outside
    /// the window (e.g. one written a week ago in Five-Year mode).
    private var hasAnyEntries: Bool { !allEntries.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if isEmpty {
                    EmptyHomeView(today: today,
                                  hasAnyEntries: hasAnyEntries,
                                  photoNote: photoNote,
                                  onCreate: openCreate)
                } else {
                    populatedHome
                }
            }
            .toolbar(.hidden, for: .navigationBar)   // we draw our own header
            #if DEBUG
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
                // Testing hook: `-openDetail` opens the first look-back entry's read sheet.
                if CommandLine.arguments.contains("-openDetail") {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        detailEntry = lookbackEntries.first
                    }
                }
            }
            #endif
        }
        .sheet(item: $composerMode) { mode in
            composerSheet(for: mode)
                .presentationBackground(Color.appSurface)
        }
        // Read-only detail, presented as a sheet (see `detailEntry`). Wrapped in a
        // NavigationStack so the reused EntryDetailView gets a bar for the Done
        // button; the environment-injected VoicePlayer carries into the sheet so the
        // voice note still plays — the same pattern the Prompts screen uses.
        .sheet(item: $detailEntry) { entry in
            NavigationStack {
                EntryDetailView(entry: entry)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { detailEntry = nil }
                        }
                    }
            }
            .presentationBackground(Color.appBackground)
        }
        .fullScreenCover(item: $viewerPhoto) { selection in
            PhotoViewerView(date: selection.date,
                            candidate: selection.candidate,
                            onDismissPhoto: { dismissPhoto(selection.candidate) })
        }
        // Re-reads the permission when the screen comes back into view — the user
        // may have changed it in the Settings app since we last looked.
        .onAppear(perform: refreshPhotoAccess)
        // Re-runs whenever anything that could change the answer changes: the
        // window, the day, the setting, the permission, or a dismissal.
        .task(id: photoTaskKey) { await refreshPhotos() }
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
                    TodayEntryBlock(entry: todayEntry,
                                    onOpen: { detailEntry = todayEntry },
                                    onEdit: { openEdit(todayEntry) })
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                } else {
                    AppButton(title: "Create your memory", action: openCreate)
                        .frame(maxWidth: 300)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                }

                ForEach(lookbackSlots) { slot in
                    RowDivider()
                    slotView(for: slot)
                }
            }
            .padding(.bottom, Spacing.xl)
        }
    }

    /// Renders one look-back slot, whatever it turned out to hold.
    @ViewBuilder
    private func slotView(for slot: LookbackSlot) -> some View {
        switch slot {
        case .entry(let entry):
            Button {
                detailEntry = entry
            } label: {
                EntryRow(entry: entry)
            }
            .buttonStyle(.plain)

        case .photo(let date, let candidate):
            LookbackPhotoRow(
                date: date,
                candidate: candidate,
                onOpen: { viewerPhoto = PhotoSelection(date: date, candidate: candidate) },
                onDismiss: { dismissPhoto(candidate) }
            )

        case .offer(let date):
            LookbackPhotoOfferRow(date: date, onTap: requestPhotoAccess)

        case .limitedAccess:
            LookbackPhotoLimitedRow(onTap: openSystemSettings)
        }
    }

    private func openCreate() { composerMode = .create }
    private func openEdit(_ entry: Entry) { composerMode = .edit(entry) }

    // MARK: - Photo look-back

    /// Everything that can change which photos belong on screen. When this string
    /// changes, `.task(id:)` cancels any in-flight lookup and starts a fresh one.
    private var photoTaskKey: String {
        "\(lookbackMode.rawValue)|\(today.timeIntervalSince1970)|\(photoLookbackEnabled)|\(photoAccess)|\(dismissalGeneration)"
    }

    /// A line for the empty state explaining why there are no photos, when there
    /// is an honest explanation to give. Silent when the feature is off or the
    /// user declined — neither is a situation that needs commentary.
    private var photoNote: String? {
        guard photoLookbackEnabled else { return nil }
        switch photoAccess {
        case .granted: return "No photos from this date either."
        case .limited: return "keepsake can only see the photos you selected."
        case .notDetermined, .denied: return nil
        }
    }

    private func refreshPhotoAccess() {
        guard photoLookbackEnabled else { return }
        photoAccess = MediaPermissions.status(of: .photoLibrary)
    }

    /// Look up one photo per empty look-back date.
    ///
    /// Runs for `.limited` as well as `.granted`: the user allowed *something*, so
    /// searching it is honest — it just usually comes back empty, which is what
    /// `LookbackPhotoLimitedRow` exists to explain.
    private func refreshPhotos() async {
        guard photoLookbackEnabled, photoAccess == .granted || photoAccess == .limited else {
            photos = [:]
            return
        }
        let lookback = PhotoLookback(blocked: PhotoDismissals.all())
        photos = await lookback.photos(for: pastTargetDates)
    }

    /// Raise the system prompt. This is the ONLY place the app asks for photo
    /// access, and it happens on a tap, in the slot the photo would fill — see
    /// `LookbackPhotoOfferRow` and CLAUDE.md before moving it.
    private func requestPhotoAccess() {
        Task { @MainActor in
            photoAccess = await MediaPermissions.request(.photoLibrary)
        }
    }

    /// Hide this photo for good, then look again — another photo from the same
    /// day may take its place.
    private func dismissPhoto(_ candidate: PhotoCandidate) {
        PhotoDismissals.add(candidate.localIdentifier)
        dismissalGeneration += 1
    }

    /// Limited access can only be widened in the Settings app; iOS won't re-ask.
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// One row of the look-back list. Built from the target dates rather than from
    /// the entries, so a date with no entry can still resolve to something.
    private enum LookbackSlot: Identifiable {
        case entry(Entry)
        case photo(date: Date, candidate: PhotoCandidate)
        /// The one-off invitation to switch photos on (topmost gap only).
        case offer(date: Date)
        /// The one-off note that "Selected Photos" limits what we can find.
        case limitedAccess(date: Date)

        var id: String {
            switch self {
            case .entry(let entry):          "entry-\(entry.id.uuidString)"
            case .photo(_, let candidate):   "photo-\(candidate.localIdentifier)"
            case .offer(let date):           "offer-\(date.timeIntervalSince1970)"
            case .limitedAccess(let date):   "limited-\(date.timeIntervalSince1970)"
            }
        }
    }

    /// What the full-screen viewer is showing. Same `Identifiable`-item pattern as
    /// the composer sheet below, for the same reason.
    private struct PhotoSelection: Identifiable {
        let date: Date
        let candidate: PhotoCandidate
        var id: String { candidate.localIdentifier }
    }

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

/// Book logo, "keepsake", today's date. (The action button lives below it,
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

            Text("keepsake")
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
/// read-only detail SHEET the look-back rows use (so a long entry can be read in
/// full without entering edit mode); the separate "Edit memory" button is the
/// explicit way to edit. The voice-note play button inside stays independently
/// tappable — the same nesting the look-back rows already rely on.
private struct TodayEntryBlock: View {
    let entry: Entry
    let onOpen: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Button(action: onOpen) {
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

/// Empty state: centred logo, wordmark, date, an invitation to write, and the
/// Create button. The invitation has two wordings — see `message`.
private struct EmptyHomeView: View {
    let today: Date
    /// Whether the journal contains any entry at all (see `JournalView.hasAnyEntries`).
    let hasAnyEntries: Bool
    /// An optional extra line explaining why photo look-back added nothing, when
    /// the user has it switched on. `nil` most of the time.
    let photoNote: String?
    let onCreate: () -> Void

    /// Two lines of copy, picked so the wording is always factually true. Saying
    /// "you haven't made any entries yet" to someone who wrote one last week (just
    /// outside the look-back window) would be wrong, so that case gets today-specific
    /// wording instead.
    private var message: (headline: String, invitation: String) {
        if hasAnyEntries {
            ("You haven't written anything today.",
             "Write down a memory so you can revisit it later.")
        } else {
            ("You haven't made any entries yet.",
             "Get started by capturing your first memory.")
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image("Home")
                .resizable()
                .scaledToFit()
                .frame(width: 110)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("keepsake")
                    .font(.kyoto(size: 32))
                    .foregroundStyle(Color.appPrimary)
                Text(today.journalHeading())
                    .font(.kyoto(size: 20))
                    .foregroundStyle(Color.appBodyText)
            }

            VStack(spacing: Spacing.xs) {
                Text(message.headline)
                Text(message.invitation)
            }
            .font(.kyoto(size: 16))
            .foregroundStyle(Color.appBodyText)
            .padding(.top, Spacing.md)

            // Only shown when the user turned photos on and we genuinely came up
            // empty — otherwise the screen would look broken rather than quiet.
            if let photoNote {
                Text(photoNote)
                    .font(.kyotoItalic(size: 14))
                    .foregroundStyle(Color.appBodyText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

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
