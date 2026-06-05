//
//  MemoryJournalApp.swift
//  MemoryJournal
//
//  The app's entry point. `@main` tells Swift this struct is where the app
//  starts. It launches a single window whose root view is `RootTabView`.
//

import SwiftUI
import SwiftData

@main
struct MemoryJournalApp: App {
    // The `ModelContainer` is SwiftData's database: it owns the on-device store
    // and hands out `ModelContext`s (the scratchpads views read & write through).
    // We create it once, here, and inject it into the view tree below so every
    // screen shares the same store.
    let container: ModelContainer

    init() {
        AppAppearance.configure()

        do {
            // `for: Entry.self` lists the model types to persist. With no other
            // options it uses a local, on-device store — exactly the privacy
            // posture the app promises.
            container = try ModelContainer(for: Entry.self)
        } catch {
            // If the store can't be created the app can't function; crash loudly
            // with the reason rather than limping on in a broken state.
            fatalError("Could not create ModelContainer: \(error)")
        }

        #if DEBUG
        // Put some sample entries in place (only when the store is empty) so the
        // dev view has something to show. Compiled out of release builds.
        SampleData.seedIfNeeded(container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            // `RootView` shows onboarding on first launch, the tab bar afterwards.
            RootView()
        }
        // Hand the container to the whole view tree. Views then reach it via
        // `@Environment(\.modelContext)` or `@Query`.
        .modelContainer(container)
    }
}
