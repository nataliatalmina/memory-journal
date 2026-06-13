//
//  PromptsView.swift
//  MemoryJournal
//
//  The Prompts tab: five date-seeded journalling prompts. Tap one to select it
//  (sage → teal); tap "Get started with prompt" to open the Phase 3 composer for
//  TODAY, pre-seeded with the prompt as the title. On save we jump to Home so the
//  new memory is visible.
//
//  One entry per day: prompts START today's entry. If today's entry already
//  exists, we don't offer a second prompt — we say so plainly and point the user
//  to today's memory. (This "already written" state isn't in the Figma; added so
//  the one-per-day rule is clearly communicated rather than silently editing.)
//

import SwiftUI
import SwiftData

struct PromptsView: View {
    @Environment(AppRouter.self) private var router

    // Used to tell whether today's entry already exists (one entry per day).
    @Query private var allEntries: [Entry]

    @State private var selectedPrompt: String?
    @State private var showComposer = false
    @State private var didSaveFromPrompt = false

    // DEBUG: preview future days without waiting for midnight. Shifts ONLY which
    // prompts are shown — never the entry's date (prompts are today-only).
    #if DEBUG
    @State private var dayOffset = 0
    #endif

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    /// The date used to *seed the prompt selection* (today, plus a DEBUG offset).
    private var seedDate: Date {
        #if DEBUG
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: today) ?? today
        #else
        return today
        #endif
    }

    private var prompts: [String] { DailyPrompts.selection(for: seedDate) }
    private var todayEntry: Entry? { allEntries.first { $0.date == today } }
    private var hasTodayEntry: Bool { todayEntry != nil }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        Text("journalling prompts")
                            .font(.kyoto(size: 24))
                            .foregroundStyle(Color.appPrimary)
                            // Sits ~64pt below the safe area so the title lands near
                            // the Figma's Y≈127 (incl. status bar), adapting per device.
                            .padding(.top, Spacing.xxxl)

                        if hasTodayEntry {
                            alreadyWrittenMessage
                        } else {
                            promptChooser
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }

                bottomButton
            }
            .animation(.easeInOut(duration: 0.25), value: selectedPrompt == nil)
        }
        .sheet(isPresented: $showComposer, onDismiss: handleComposerDismiss) {
            // Only reachable when there's no entry today, so this always creates
            // a new entry, dated today, seeded with the prompt.
            ComposerView(date: today,
                         existingEntry: nil,
                         prompt: selectedPrompt,
                         onSaved: { didSaveFromPrompt = true })
                .presentationBackground(Color.appSurface)
        }
        #if DEBUG
        .onAppear {
            if CommandLine.arguments.contains("-selectFirstPrompt") {
                selectedPrompt = prompts.first
            }
            if CommandLine.arguments.contains("-openPromptComposer") {
                selectedPrompt = prompts.first
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    showComposer = true
                }
            }
        }
        #endif
    }

    // MARK: - Choose-a-prompt state (no entry yet today)

    private var promptChooser: some View {
        VStack(spacing: Spacing.lg) {
            Text("Not sure where to begin? Get started with one of these prompts:")
                .font(.kyoto(size: 16))
                .foregroundStyle(Color.appBodyText)
                .multilineTextAlignment(.center)

            #if DEBUG
            daySimulator
            #endif

            VStack(spacing: Spacing.md) {
                ForEach(prompts, id: \.self) { prompt in
                    PromptCard(text: prompt, isSelected: selectedPrompt == prompt) {
                        toggle(prompt)
                    }
                }
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Already-written state (today's entry exists)

    private var alreadyWrittenMessage: some View {
        // Sits at the same position as the intro on the normal screen: same title
        // above (identical padding) + the same `Spacing.lg` gap from the parent
        // VStack. No extra top padding, so the title + first line of text line up
        // exactly with the choose-a-prompt state.
        VStack(spacing: Spacing.sm) {
            Text("You've already written today's memory.")
            Text("There's one entry a day — fresh prompts arrive tomorrow.")
        }
        .font(.kyoto(size: 16))
        .foregroundStyle(Color.appBodyText)
        .multilineTextAlignment(.center)
    }

    // MARK: - Bottom button (changes with state)

    @ViewBuilder
    private var bottomButton: some View {
        if hasTodayEntry {
            AppButton(title: "View today's memory") { router.selectedTab = .journal }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
        } else if selectedPrompt != nil {
            AppButton(title: "Get started with prompt") { showComposer = true }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Actions

    private func toggle(_ prompt: String) {
        // Single selection; tapping the selected card again clears it.
        selectedPrompt = (selectedPrompt == prompt) ? nil : prompt
    }

    private func handleComposerDismiss() {
        // Only jump to Home if the entry was actually saved (not a swipe-cancel).
        guard didSaveFromPrompt else { return }
        didSaveFromPrompt = false
        selectedPrompt = nil
        router.selectedTab = .journal   // land on Home to see the new memory
    }

    #if DEBUG
    /// DEBUG-only control to fake "tomorrow" and confirm the daily set is stable
    /// per day and changes across days. Compiled out of release builds.
    private var daySimulator: some View {
        VStack(spacing: Spacing.xs) {
            Text("DEBUG — prompt day: \(seedDate.journalHeading())")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            HStack {
                Button("−1 day") { dayOffset -= 1; selectedPrompt = nil }
                Button("Today") { dayOffset = 0; selectedPrompt = nil }
                Button("+1 day") { dayOffset += 1; selectedPrompt = nil }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.vertical, Spacing.xs)
    }
    #endif
}

/// One selectable prompt card. An UNSELECTED card is a normal, fully tappable
/// button (sage) — not a disabled control. Selected → teal.
private struct PromptCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.kyoto(size: 16))
                // Selected: white on solid teal. Unselected: teal text on a pale
                // teal fill — clearly distinct from a solid-teal CTA, high-contrast.
                .foregroundStyle(isSelected ? Color.white : Color.appPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isSelected ? Color.appPrimary : Color.appPrimary.opacity(0.10),
                            in: .rect(cornerRadius: CornerRadius.card))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    PromptsView()
        .modelContainer(for: Entry.self, inMemory: true)
        .environment(AppRouter())
}
