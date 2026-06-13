//
//  AppRouter.swift
//  MemoryJournal
//
//  Owns which bottom tab is selected, so screens can switch tabs (e.g. after
//  saving a prompted entry, jump to Home to see it). `@Observable` means SwiftUI
//  re-renders anything reading it when `selectedTab` changes; we inject one
//  instance into the environment from the app.
//

import SwiftUI

@Observable
final class AppRouter {
    var selectedTab: AppTab

    init() {
        #if DEBUG
        selectedTab = AppRouter.debugInitialTab() ?? .journal
        #else
        selectedTab = .journal
        #endif
    }

    #if DEBUG
    /// Honour a `-startTab <name>` launch argument for screenshots/testing.
    private static func debugInitialTab() -> AppTab? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-startTab"), i + 1 < args.count else { return nil }
        switch args[i + 1] {
        case "journal": return .journal
        case "calendar": return .calendar
        case "prompts": return .prompts
        case "settings": return .settings
        case "dev": return .dev
        default: return nil
        }
    }
    #endif
}
