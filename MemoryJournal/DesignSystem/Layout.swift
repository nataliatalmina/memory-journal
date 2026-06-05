//
//  Layout.swift
//  MemoryJournal
//
//  Spacing and corner-radius scales. Reference these instead of hard-coding
//  numbers so padding, gaps, and rounded shapes stay consistent everywhere.
//

import CoreGraphics

/// Spacing scale for padding and gaps between views.
/// Values grow in roughly even steps; pick the closest one rather than a raw number.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Corner-radius scale, kept small on purpose so buttons and cards feel related.
/// Starting values — tune against the Figma once exact radii are known.
enum CornerRadius {
    /// Full-width call-to-action buttons (substantial, per the designs).
    static let button: CGFloat = 18
    /// Floating cards — calendar card, journal entry card, etc.
    static let card: CGFloat = 24
}
