//
//  CalendarView.swift
//  MemoryJournal
//
//  The Calendar tab (Phase 5). A month grid in a white card; tap a day to see the
//  entry written on THAT EXACT date below the card, or an empty message if none.
//
//  This screen is PURE LOOK-UP of a single date — and READ-ONLY. Unlike Home (which
//  resurfaces the same calendar date across the past N years/months), the Calendar
//  shows only the one selected date. It never opens the composer, never creates,
//  never edits. Tapping a day with an entry shows it via the shared, read-only
//  `EntryReadContent` (the same presentation Home's detail screen uses).
//
//  Decisions (recorded in CLAUDE.md):
//   • Forward navigation is CAPPED at the current month — future dates can't have
//     entries, so the next chevron is disabled once you reach this month.
//   • DEFAULT selection is none (matches the mockup): on open, today shows as plain
//     text and a gentle hint sits below the card until the user taps a day.
//   • Days that HAVE an entry get a small teal dot under the number.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    // One local calendar for the whole screen, shared with `Entry.date`'s
    // normalisation (Phase 1): same locale, same time zone, so a tapped grid day
    // compares exactly against a stored entry's start-of-day date.
    private let calendar = Calendar.current

    // `@Query` fetches from SwiftData and re-runs whenever the store changes, so the
    // entry dots and the shown entry stay live (e.g. if an entry is added on Home).
    // The journal holds few entries, so fetching all and filtering in-memory is
    // simple and cheap — the same approach Home uses.
    @Query(sort: \Entry.date, order: .reverse) private var allEntries: [Entry]

    // The month currently on screen, stored as that month's first-day anchor.
    @State private var displayedMonth: Date
    // The day the user tapped (start-of-day), or nil when nothing is selected.
    @State private var selectedDate: Date?

    init() {
        // Start on the current month. (`@State` needs an initial value; we build it
        // here from "now" so the calendar opens on this month.)
        let cal = Calendar.current
        _displayedMonth = State(initialValue: CalendarMonth(containing: .now, calendar: cal).firstDay)
    }

    // The grid maths for the displayed month (pure helper, see CalendarMonth.swift).
    private var month: CalendarMonth {
        CalendarMonth(containing: displayedMonth, calendar: calendar)
    }

    // First day of the *current* real month — the forward-navigation ceiling.
    private var currentMonthStart: Date {
        CalendarMonth(containing: .now, calendar: calendar).firstDay
    }

    // Can we page forward? Only while we're before the current month.
    private var canGoForward: Bool { displayedMonth < currentMonthStart }

    // The set of dates that have an entry — drives the entry dots. `Entry.date` is
    // already start-of-day, so these line up with the grid's start-of-day dates.
    private var datesWithEntries: Set<Date> { Set(allEntries.map(\.date)) }

    // The entry on the selected date, if any. (`@Query` is newest-first; the app
    // enforces one entry per date via the composer, so `first` is that entry.)
    private var selectedEntry: Entry? {
        guard let selectedDate else { return nil }
        return allEntries.first { $0.date == selectedDate }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.lg) {
                    monthHeader
                        .padding(.top, Spacing.xl)

                    calendarCard
                        .padding(.horizontal, Spacing.lg)

                    belowCard
                }
                .padding(.bottom, Spacing.xl)
            }
        }
        // Animate the swap between hint / entry / empty-message and month changes.
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
        .animation(.easeInOut(duration: 0.2), value: displayedMonth)
        #if DEBUG
        .onAppear(perform: applyDebugLaunchArguments)
        #endif
    }

    // MARK: - Month header (chevrons + "August 2026")

    private var monthHeader: some View {
        HStack {
            chevron(.backward, enabled: true, label: "Previous month") {
                changeMonth(to: month.previous())
            }
            Spacer()
            Text(month.title)
                .font(.kyoto(size: 24))
                .foregroundStyle(Color.appPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            // Disabled (and dimmed) on the current month so the user can't page into
            // always-empty future months.
            chevron(.forward, enabled: canGoForward, label: "Next month") {
                changeMonth(to: month.next())
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    /// A single chevron button with a 44×44 tap target (HIG minimum). When
    /// disabled it dims and stops responding.
    private func chevron(_ direction: ChevronDirection, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: direction == .backward ? "chevron.left" : "chevron.right")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
        .accessibilityLabel(label)
    }

    private enum ChevronDirection { case backward, forward }

    // MARK: - The white calendar card

    private var calendarCard: some View {
        VStack(spacing: Spacing.md) {
            weekdayHeaderRow
            dayGrid
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.lg)
        .background(Color.appSurface, in: .rect(cornerRadius: CornerRadius.largeCard))
    }

    /// SUN…SAT (in the locale's order), derived from `Calendar` — not hardcoded.
    private var weekdayHeaderRow: some View {
        HStack(spacing: 0) {
            // `enumerated()` gives us a stable index to use as the `id`, so we don't
            // rely on the label strings themselves being unique.
            ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.kyoto(size: 13))
                    .foregroundStyle(Color.appBodyText.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)   // each day cell already announces its full date
    }

    /// The 7-column grid of day cells. `LazyVGrid` lays children out in columns; we
    /// give it 7 equal flexible columns and feed it the row-major grid cells.
    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(Array(month.gridDays.enumerated()), id: \.offset) { _, date in
                if let date {
                    DayCell(
                        date: date,
                        dayNumber: calendar.component(.day, from: date),
                        isSelected: date == selectedDate,
                        hasEntry: datesWithEntries.contains(date),
                        onTap: { select(date) }
                    )
                } else {
                    // A blank cell (before the 1st / after the last day). Color.clear
                    // still occupies its grid slot so the real days stay aligned.
                    Color.clear.frame(height: 52)
                }
            }
        }
    }

    // MARK: - Below the card (hint / entry / empty message)

    @ViewBuilder
    private var belowCard: some View {
        if let entry = selectedEntry {
            // Entry exists: a full-width divider, then the SAME read-only entry
            // presentation Home uses (so it's visually identical and never editable).
            VStack(spacing: Spacing.lg) {
                Rectangle()
                    .fill(Color.appPrimary.opacity(0.35))
                    .frame(height: 0.5)

                EntryReadContent(entry: entry)
                    .padding(.horizontal, Spacing.lg)
            }
        } else if selectedDate != nil {
            // A day is selected but has no entry.
            Text("There are no entries on this date.")
                .font(.kyotoItalic(size: 16))
                .foregroundStyle(Color.appBodyText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
        } else {
            // Default state: nothing selected yet (matches the mockup). A quiet hint
            // so the screen isn't inert.
            Text("Select a date to see your memory for that day.")
                .font(.kyoto(size: 16))
                .foregroundStyle(Color.appBodyText.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Actions

    private func select(_ date: Date) {
        // Normalise to start-of-day (defensive — grid dates already are) so it
        // matches `Entry.date` exactly.
        selectedDate = calendar.startOfDay(for: date)
    }

    private func changeMonth(to newMonth: CalendarMonth) {
        displayedMonth = newMonth.firstDay
        // The previously selected day isn't visible in the new month, so clear it —
        // the screen returns to the hint until the user taps a day here.
        selectedDate = nil
    }

    #if DEBUG
    /// Screenshot/testing hooks (compiled out of release builds):
    ///   • `-calendarSelectEntry` — jump to the newest entry's month and select it
    ///     (the "date with entry" state).
    ///   • `-calendarSelectToday` — select today (the default seed has no entry
    ///     today, so this shows the "no entries on this date" state).
    private func applyDebugLaunchArguments() {
        let args = CommandLine.arguments
        if args.contains("-calendarSelectToday") {
            selectedDate = calendar.startOfDay(for: .now)
        }
        if args.contains("-calendarSelectEntry") {
            Task { @MainActor in
                // Small delay so `@Query` has populated `allEntries` first.
                try? await Task.sleep(for: .seconds(0.4))
                guard let newest = allEntries.first else { return }   // newest-first sort
                displayedMonth = CalendarMonth(containing: newest.date, calendar: calendar).firstDay
                selectedDate = newest.date
            }
        }
    }
    #endif
}

/// One day cell: the number, an optional filled-teal selection circle, and a small
/// entry dot. The whole cell is a button with a ≥44pt tap target.
private struct DayCell: View {
    let date: Date
    let dayNumber: Int
    let isSelected: Bool
    let hasEntry: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.kyoto(size: 18))
                    // Selected: white on a solid teal circle. Otherwise: plain grey
                    // (today is NOT specially marked — matches the mockup).
                    .foregroundStyle(isSelected ? Color.white : Color.appBodyText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)   // shrink rather than clip at large Dynamic Type
                    .frame(width: 40, height: 40)
                    .background {
                        if isSelected {
                            Circle().fill(Color.appPrimary)
                        }
                    }

                // Entry dot. Always laid out (opacity 0 when absent) so rows don't
                // shift between days with and without entries. Hidden when selected —
                // the teal circle is already the indicator.
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 5, height: 5)
                    .opacity(hasEntry && !isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.journalHeading())
        .accessibilityValue(hasEntry ? "Has an entry" : "No entry")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Entry.self, inMemory: true)
}
