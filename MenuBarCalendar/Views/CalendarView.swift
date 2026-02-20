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

            Divider().frame(height: 1).background(.windowBackground)

            CalendarGridView(
                calendarManager: calendarManager,
                month: calendarManager.currentMonth,
                hoveredDate: $hoveredDate
            )

            Divider().frame(height: 1).background(.windowBackground)

            EventsListView(calendarManager: calendarManager)

            Divider().frame(height: 1).background(.windowBackground)

            CalendarToolBarView()
        }
        .padding(10)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .background(.windowBackground)
    }
}
