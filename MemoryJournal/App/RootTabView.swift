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

struct RootTabView: View {
    var body: some View {
        // `TabView` with the modern `Tab` API (iOS 18+): each `Tab` takes a
        // label, an SF Symbol for its icon, and the view shown when selected.
        // Labels are lowercase to match the app's editorial styling.
        // Icons are outline ("line-art") SF Symbols as stand-ins for the
        // custom icons that will come from Figma later.
        TabView {
            Tab("journal", systemImage: "book") {
                JournalView()
            }
            Tab("calendar", systemImage: "calendar") {
                CalendarView()
            }
            Tab("prompts", systemImage: "text.bubble") {
                PromptsView()
            }
            Tab("settings", systemImage: "gearshape") {
                SettingsView()
            }

            // DEBUG-only tab for verifying the data layer (Phase 1). It is
            // compiled out of release builds, so users never see it.
            #if DEBUG
            Tab("dev", systemImage: "ladybug") {
                DateLookupDevView()
            }
            #endif
        }
        .tint(.appPrimary)   // deep teal for the active tab's icon + label
    }
}

#Preview {
    RootTabView()
}
