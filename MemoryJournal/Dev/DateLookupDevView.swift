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

                Section("Onboarding") {
                    LabeledContent("Chosen view-mode", value: savedMode.title)
                    // Flipping this flag false makes RootView swap back to the
                    // onboarding flow immediately — handy for re-testing it.
                    Button("Replay onboarding", role: .destructive) {
                        hasOnboarded = false
                    }
                }
            }
            .navigationTitle("DateLookup dev")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: runQuery)
    }

    /// The dates the current settings will search for (shown in the UI).
    private var searchedDates: [Date] {
        DateLookup().targetDates(matching: targetDate, mode: mode, count: count)
    }

    private func runQuery() {
        let lookup = DateLookup()
        results = (try? lookup.matchingEntries(matching: targetDate, mode: mode, count: count, in: context)) ?? []

        // Also dump to the console, as requested.
        print("— DateLookup [\(mode.rawValue)] N=\(count) target \(formatted(targetDate)) → \(results.count) match(es):")
        for entry in results {
            print("    • \(formatted(entry.date))  \(entry.title ?? "")")
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    DateLookupDevView()
        .modelContainer(for: Entry.self, inMemory: true)
}
#endif
