//
//  DateLookupDevView.swift
//  MemoryJournal
//
//  A throwaway, DEBUG-only screen for verifying the DateLookup logic against the
//  seeded data BEFORE the real Journal UI exists (that's Phase 3). Punch in a
//  target date + mode + count and see exactly which dates are searched and which
//  entries match. Also prints the matches to the Xcode console.
//

#if DEBUG
import SwiftUI
import SwiftData

struct DateLookupDevView: View {
    // `@Environment(\.modelContext)` hands us the SwiftData "context" for this
    // view — the in-memory scratchpad where we read/write models. The context
    // belongs to the `ModelContainer` we attach to the app in MemoryJournalApp.
    @Environment(\.modelContext) private var context

    @State private var targetDate = Date()
    @State private var mode: DateLookup.Mode = .years
    @State private var count = 5
    @State private var results: [Entry] = []

    // Onboarding preferences, so the dev tab can show the chosen mode and reset
    // the flow for re-testing.
    @AppStorage(PreferenceKey.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferenceKey.lookbackMode) private var savedMode: LookbackMode = .fiveMonths

    var body: some View {
        NavigationStack {
            Form {
                // FIRST, deliberately. The sections below grow with the seeded
                // data, and this screen sits under the custom tab bar — anything
                // at the bottom of this Form ends up unreachable (see the
                // `.contentMargins` note below). The controls you actually reach
                // for while testing belong at the top.
                Section("Onboarding") {
                    LabeledContent("Chosen view-mode", value: savedMode.title)
                    // Flipping this flag false makes RootView swap back to the
                    // onboarding flow immediately — handy for re-testing it.
                    Button("Replay onboarding", role: .destructive) {
                        hasOnboarded = false
                    }
                }

                Section("Query") {
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                    Picker("Mode", selection: $mode) {
                        Text("Years").tag(DateLookup.Mode.years)
                        Text("Months").tag(DateLookup.Mode.months)
                    }
                    .pickerStyle(.segmented)
                    Stepper("Look back N = \(count)", value: $count, in: 1...12)
                    Button("Run query", action: runQuery)
                }

                Section("Dates searched (most recent first)") {
                    ForEach(searchedDates, id: \.self) { date in
                        Text(formatted(date))
                            .font(.system(.body, design: .monospaced))
                    }
                }

                Section("Matched entries — \(results.count)") {
                    if results.isEmpty {
                        Text("No matches").foregroundStyle(.secondary)
                    } else {
                        ForEach(results) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatted(entry.date))
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(Color.appPrimary)
                                Text(entry.title ?? "(no title)").fontWeight(.medium)
                                Text(entry.body)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button("Reseed sample data") {
                        SampleData.reseed(context)
                        runQuery()
                    }
                    Button("Clear all entries (empty state)", role: .destructive) {
                        SampleData.clearAll(context)
                        runQuery()
                    }
                }

            }
            .navigationTitle("DateLookup dev")
            .navigationBarTitleDisplayMode(.inline)
            // The custom tab bar is added with `.safeAreaInset` on the ZStack in
            // RootTabView, and a `Form` nested inside this NavigationStack doesn't
            // pick that inset up — so its last rows sat under the bar with no way
            // to scroll them clear. The app's other screens are plain ScrollViews
            // with their own generous bottom padding, which is why only this one
            // is affected. 100pt comfortably clears the bar on every device.
            .contentMargins(.bottom, 100, for: .scrollContent)
        }
        .onAppear(perform: runQuery)
    }

    /// The DatePicker hands back a raw local instant; canonicalise it before it
    /// reaches DateLookup, exactly as the real screens do with `.journalToday`.
    private var canonicalTarget: Date { targetDate.journalDay() }

    /// The dates the current settings will search for (shown in the UI).
    private var searchedDates: [Date] {
        DateLookup().targetDates(matching: canonicalTarget, mode: mode, count: count)
    }

    private func runQuery() {
        let lookup = DateLookup()
        results = (try? lookup.matchingEntries(matching: canonicalTarget, mode: mode, count: count, in: context)) ?? []

        // Also dump to the console, as requested.
        print("— DateLookup [\(mode.rawValue)] N=\(count) target \(formatted(canonicalTarget)) → \(results.count) match(es):")
        for entry in results {
            print("    • \(formatted(entry.date))  \(entry.title ?? "")")
        }
    }

    /// Reuses the app's own heading formatter, which is UTC-pinned — entry dates
    /// are UTC midnights, so the device's zone would render them a day early west
    /// of UTC.
    private func formatted(_ date: Date) -> String {
        date.journalHeading()
    }
}

#Preview {
    DateLookupDevView()
        .modelContainer(for: Entry.self, inMemory: true)
}
#endif
