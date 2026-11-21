//
//  Formatters.swift
//  MenuBarCalendar
//

import Foundation

/// Shared, lazily created date formatters. Creating a `DateFormatter` is
/// expensive, and SwiftUI view bodies are evaluated very often.
enum Formatters {
    private static func make(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// Time of day, respecting the user's 12/24-hour setting ("14:30" / "2:30 PM").
    static let time = make(template: "jmm")

    /// Full weekday name ("Montag").
    static let weekday = make(template: "EEEE")

    /// Localized month and year for the calendar header ("November 2026").
    static let monthYear = make(template: "MMMMyyyy")

    /// Long date ("21. November 2026").
    static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .long
        return formatter
    }()
}
