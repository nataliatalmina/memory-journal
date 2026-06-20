//
//  RootTabView.swift
//  MemoryJournal
//
//  The app's root screen: the four main sections above a CUSTOM bottom tab bar
//  (`MemoryTabBar`), in the order from the designs — Journal, Calendar, Prompts,
//  Settings.
//
//  We don't use SwiftUI's `TabView`: its native bar can't express the bespoke
//  hand-drawn icons + italic-serif labels of the design. Instead we keep all four
//  screens alive in a `ZStack` (so each tab preserves its own state — scroll
//  position, the Calendar's selected day, a pushed Journal detail — exactly like a
//  real tab bar) and show only the selected one. The custom bar is attached with
//  `.safeAreaInset(edge: .bottom)`, the idiomatic way to add a bottom bar: it
//  reserves space so each screen's content insets correctly above the bar across
//  all device sizes.
//

import SwiftUI

enum AppTab: Hashable {
    case journal, calendar, prompts, settings
    #if DEBUG
    case dev
    #endif
}

struct RootTabView: View {
    // The selected tab lives in the shared `AppRouter` so other screens can switch
    // tabs (e.g. jump to Home after saving a prompted entry).
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router   // makes `$router.selectedTab` a binding

        ZStack {
            screen(.journal)
            screen(.calendar)
            screen(.prompts)
            screen(.settings)
            #if DEBUG
            screen(.dev)
            #endif
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MemoryTabBar(selection: $router.selectedTab)
        }
        .tint(.appPrimary)   // global accent for any default-tinted controls
    }

    /// One tab's screen, shown only when selected. Kept in the hierarchy when
    /// hidden (opacity 0) so its `@State` survives tab switches; `allowsHitTesting`
    /// and `accessibilityHidden` keep the hidden screens out of touch and VoiceOver.
    @ViewBuilder
    private func screen(_ tab: AppTab) -> some View {
        let isSelected = router.selectedTab == tab
        content(tab)
            .opacity(isSelected ? 1 : 0)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    @ViewBuilder
    private func content(_ tab: AppTab) -> some View {
        switch tab {
        case .journal:  JournalView()
        case .calendar: CalendarView()
        case .prompts:  PromptsView()
        case .settings: SettingsView()
        #if DEBUG
        case .dev:      DateLookupDevView()
        #endif
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppRouter())
        .environment(AppLock())
}
