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

        // Italic-serif font on the tab labels.
        // TODO(PP Kyoto): use UIFont(name: "PPKyoto-MediumItalic", size: 11)
        // once the custom font is registered; until then, system serif italic.
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: serifItalicFont(size: 11)
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

    /// Closest built-in italic serif as a `UIFont`.
    /// (UIKit needs a `UIFont` here, not a SwiftUI `Font` — different types.)
    private static func serifItalicFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size)
        if let descriptor = base.fontDescriptor
            .withDesign(.serif)?
            .withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base   // fall back to plain system font if the serif isn't available
    }
}
