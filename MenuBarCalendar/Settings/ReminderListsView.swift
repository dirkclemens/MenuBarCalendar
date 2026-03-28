//
//  ReminderListsView.swift
//

import SwiftUI
import EventKit

struct ReminderListsView: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(calendarManager.reminderLists, id: \.calendarIdentifier) { list in
                ReminderListToggleRow(calendarManager: calendarManager, reminderList: list)
            }
        }
    }
}

struct ReminderListToggleRow: View {
    @ObservedObject var calendarManager: CalendarManager
    let reminderList: EKCalendar

    var body: some View {
        Toggle(isOn: Binding(
            get: { calendarManager.isReminderListEnabled(reminderList) },
            set: { _ in calendarManager.toggleReminderList(reminderList) }
        )) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(cgColor: reminderList.cgColor))
                    .frame(width: 10, height: 10)
                Text(reminderList.title)
                    .font(.system(size: 12))
            }
        }
        .toggleStyle(.checkbox)
    }
}
