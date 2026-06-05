//
//  Color+Theme.swift
//  MemoryJournal
//
//  The app's colour palette — the single source of truth.
//  Rule (from CLAUDE.md): never write raw hex in views. Always reference
//  one of the named colours below, e.g. `Color.appPrimary`.
//

import SwiftUI

extension Color {
    /// Deep teal `#005363` — primary buttons, headings, active tab, selected calendar day.
    static let appPrimary = Color(hex: 0x005363)

    /// Muted sage-teal `#5D909B` — secondary / disabled-style buttons (e.g. "Enable Photo Library").
    static let appSecondary = Color(hex: 0x5D909B)

    /// Pale blue-grey `#ECEFF5` — the app background, used on almost every screen.
    static let appBackground = Color(hex: 0xECEFF5)

    /// Off-white `#FBFCFD` — cards / surfaces (calendar card, journal entry card, tab bar).
    static let appSurface = Color(hex: 0xFBFCFD)

    /// Warm grey `#525252` — body text throughout the app, including journal entries.
    static let appBodyText = Color(hex: 0x525252)
}

extension Color {
    /// Build a `Color` from a hex literal like `0x005363`.
    ///
    /// SwiftUI's `Color` has no built-in hex initialiser, so we add one.
    /// We pull each colour channel out of the number with bit-shifting:
    ///   - `hex >> 16` moves the red byte down to the lowest 8 bits, `& 0xFF` keeps just those bits.
    ///   - `hex >> 8`  does the same for green.
    ///   - `hex & 0xFF` is already the blue byte.
    /// Each byte is 0–255, so we divide by 255 to get the 0–1 value SwiftUI expects.
    init(hex: UInt, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
