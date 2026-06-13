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
    static let xxxl: CGFloat = 64
}

/// Corner-radius scale, kept small on purpose so buttons and cards feel related.
/// Values confirmed against the Phase 2 Figma onboarding screens.
enum CornerRadius {
    /// Small pill — the period chips on the view-mode cards (Figma ≈ 2.88).
    static let chip: CGFloat = 3
    /// Full-width call-to-action buttons (Figma: 12).
    static let button: CGFloat = 12
    /// Onboarding selection cards (Figma: 12). The large floating cards on the
    /// calendar/journal screens may differ — revisit when we build Phase 5.
    static let card: CGFloat = 12
}
