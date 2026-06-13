//
//  RootTabView.swift
//  MemoryJournal
//
//  The app's root screen: a bottom tab bar with the four main sections,
//  in the order from the designs — journal, calendar, prompts, settings.
//
//  Phase 0 uses placeholder content in each tab. The real screens arrive in
//  later phases; this file shouldn't need to change much when they do.
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

        // `TabView` with the modern `Tab` API (iOS 18+): each `Tab` takes a
        // label, an SF Symbol for its icon, a `value` for selection, and the view
        // shown when selected. Labels are lowercase to match the editorial style;
        // icons are outline ("line-art") SF Symbols, stand-ins for custom icons.
        return TabView(selection: $router.selectedTab) {
            Tab("journal", systemImage: "book", value: AppTab.journal) {
                JournalView()
            }
            Tab("calendar", systemImage: "calendar", value: AppTab.calendar) {
                CalendarView()
            }
            Tab("prompts", systemImage: "text.bubble", value: AppTab.prompts) {
                PromptsView()
            }
            Tab("settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }

            // DEBUG-only tab for verifying the data layer (Phase 1). It is
            // compiled out of release builds, so users never see it.
            #if DEBUG
            Tab("dev", systemImage: "ladybug", value: AppTab.dev) {
                DateLookupDevView()
            }
            #endif
        }
        .tint(.appPrimary)   // deep teal for the active tab's icon + label
    }
}

#Preview {
    RootTabView()
        .environment(AppRouter())
}
