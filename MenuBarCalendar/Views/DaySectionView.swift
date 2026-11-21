//
// DaySectionView.swift
//

import SwiftUI
import EventKit

struct DaySectionView: View {
    let day: Date
    let dayLabel: String
    let dateLabel: String
    let events: [EKEvent]
    let reminders: [EKReminder]

    init(day: Date, dayLabel: String, dateLabel: String, events: [EKEvent], reminders: [EKReminder] = []) {
        self.day = day
        self.dayLabel = dayLabel
        self.dateLabel = dateLabel
        self.events = events
        self.reminders = reminders
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dayLabel)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(dateLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Recurring and multi-day events share one eventIdentifier, so the row id
            // also includes the day and the occurrence's start date.
            ForEach(events.map { (id: EventsListView.rowID(day: day, event: $0), event: $0) }, id: \.id) { row in
                EventRowView(event: row.event)
                    .id(row.id)
            }
            
            ForEach(reminders, id: \.calendarItemIdentifier) { reminder in
                ReminderRowView(reminder: reminder)
            }
        }
    }
}
