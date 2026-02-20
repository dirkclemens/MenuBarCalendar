//
// CalendarsListView.swift
//

import SwiftUI
import EventKit

struct CalendarsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var groupedCalendars: [(String, [EKCalendar])] {
        var groups: [String: [EKCalendar]] = [:]
        for calendar in calendarManager.calendars {
            let sourceName = calendar.source.title
            if groups[sourceName] == nil { groups[sourceName] = [] }
            groups[sourceName]?.append(calendar)
        }
        return groups.sorted { first, second in
            if first.key.lowercased().contains("icloud") { return true }
            if second.key.lowercased().contains("icloud") { return false }
            return first.key < second.key
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedCalendars, id: \.0) { sourceName, calendars in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceName)
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
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
