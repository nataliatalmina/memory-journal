//
//  LookbackMode.swift
//  MemoryJournal
//
//  The user's chosen "how far back do I look?" window. This is the single
//  source of truth that the journal's same-date query reads, that onboarding
//  first writes, and that Settings (Phase 6) will later edit.
//

import Foundation

/// Five-month vs five-year look-back. Backed by a `String` raw value so it can
/// be stored directly with `@AppStorage` (which persists to UserDefaults).
enum LookbackMode: String, CaseIterable, Identifiable {
    case fiveMonths
    case fiveYears

    var id: String { rawValue }

    /// How many steps back we show, including the current one. Both modes use 5
    /// ("five months" / "five years"), per the designs.
    static let count = 5

    /// Card heading in the picker.
    var title: String {
        switch self {
        case .fiveMonths: "Five-Month View"
        case .fiveYears:  "Five-Year View"
        }
    }

    /// Card description in the picker (matches the Figma copy).
    var detail: String {
        switch self {
        case .fiveMonths: "See entries from the same date across five months. Ideal for starting your journey."
        case .fiveYears:  "See entries from the same date across five years. Perfect for long-term reflection."
        }
    }

    /// Bridges this user-facing choice to the `DateLookup` engine from Phase 1.
    var lookupMode: DateLookup.Mode {
        switch self {
        case .fiveMonths: .months
        case .fiveYears:  .years
        }
    }

    /// Example period labels shown as little chips on the card. Computed from
    /// "now" so they stay accurate over time (the Figma shows them static; making
    /// them dynamic is a deliberate, small improvement — flagged in the summary).
    /// e.g. years → ["2026","2025","2024","2023","2022"];
    ///      months → ["June","May","April","March","February"].
    func exampleChips(asOf date: Date = .now, calendar: Calendar = .current) -> [String] {
        switch self {
        case .fiveYears:
            let year = calendar.component(.year, from: date)
            return (0..<Self.count).map { String(year - $0) }

        case .fiveMonths:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = .current
            formatter.setLocalizedDateFormatFromTemplate("LLLL") // standalone full month name
            return (0..<Self.count).compactMap { monthsBack in
                calendar.date(byAdding: .month, value: -monthsBack, to: date).map(formatter.string)
            }
        }
    }
}
