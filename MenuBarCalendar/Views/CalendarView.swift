//
//  CalendarView.swift
//

import SwiftUI
import EventKit

struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var hoveredDate: Date?

    var body: some View {
        VStack(spacing: 0) {
            CalendarNavigationView(calendarManager: calendarManager)

            CalendarGridView(
                calendarManager: calendarManager,
                month: calendarManager.currentMonth,
                hoveredDate: $hoveredDate
            )

            EventsListView(calendarManager: calendarManager)
        }
        .frame(maxHeight: .infinity)
    }
}
