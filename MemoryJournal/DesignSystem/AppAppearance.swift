//
//  AppAppearance.swift
//  MemoryJournal
//
//  App-wide chrome styling that SwiftUI can't fully express on its own.
//
//  SwiftUI's `TabView` draws its bar through UIKit under the hood, so to get the
//  italic-serif tab labels and the surface-coloured bar from the designs we have
//  to configure `UITabBarAppearance` (a UIKit type). CLAUDE.md allows reaching
//  into UIKit when a feature genuinely needs it — this is that case, kept to one
//  small, clearly-marked file. `configure()` is called once at app launch.
//

import SwiftUI
import UIKit

enum AppAppearance {
    /// Apply the global tab bar styling. Call once, at app start-up.
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appSurface)   // off-white tab bar

        // Italic-serif font on the tab labels: PP Kyoto Medium Italic.
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: tabLabelFont(size: 11)
        ]

        // A tab bar has several layouts (stacked on phones, inline/compact on
        // larger sizes). Apply the same label font to each so it's consistent.
        for layout in [appearance.stackedLayoutAppearance,
                       appearance.inlineLayoutAppearance,
                       appearance.compactInlineLayoutAppearance] {
            layout.normal.titleTextAttributes = labelAttributes
            layout.selected.titleTextAttributes = labelAttributes
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// PP Kyoto Medium Italic as a `UIFont` (UIKit needs a `UIFont` here, not a
    /// SwiftUI `Font`). Falls back to the system font if the custom font isn't
    /// registered for some reason.
    private static func tabLabelFont(size: CGFloat) -> UIFont {
        UIFont(name: "PPKyoto-MediumItalic", size: size) ?? .systemFont(ofSize: size)
    }
}
