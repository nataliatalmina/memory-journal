//
//  DateFormatting.swift
//  MemoryJournal
//
//  Shared date formatting for the journal. The designs show dates lowercased
//  with the full month name, e.g. "15 august 2026".
//

import Foundation

extension Date {
    /// "15 august 2026" — day, full month name, year, lowercased.
    /// Used for the home header date and each look-back row's heading.
    func journalHeading() -> String {
        Self.headingFormatter.string(from: self).lowercased()
    }

    // A `DateFormatter` is relatively expensive to build, so we make one and
    // reuse it. `setLocalizedDateFormatFromTemplate` lets the user's locale pick
    // the right field order (e.g. "june 6 2026" in the US) while we ask for
    // day + full month + year.
    private static let headingFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter
    }()
}
