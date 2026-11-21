//
// CalendarsListView.swift
//

import SwiftUI
import EventKit

struct CalendarsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private struct SourceGroup: Identifiable {
        let id: String
        let title: String
        let calendars: [EKCalendar]
    }

    /// Calendars grouped by account; iCloud first, then alphabetically.
    private var groupedCalendars: [SourceGroup] {
        Dictionary(grouping: calendarManager.calendars) { $0.source.sourceIdentifier }
            .map { id, calendars in
                SourceGroup(
                    id: id,
                    title: calendars.first?.source.title ?? "",
                    calendars: calendars.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                )
            }
            .sorted { first, second in
                let firstIsICloud = first.title.localizedCaseInsensitiveContains("icloud")
                let secondIsICloud = second.title.localizedCaseInsensitiveContains("icloud")
                if firstIsICloud != secondIsICloud { return firstIsICloud }
                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedCalendars) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                            CalendarSelectionView(
                                calendar: calendar,
                                isEnabled: calendarManager.isCalendarEnabled(calendar),
                                onToggle: { calendarManager.toggleCalendar(calendar) }
                            )
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}
