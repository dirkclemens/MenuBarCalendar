//
// CalendarNavigationView.swift
//

import SwiftUI

struct CalendarNavigationView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: calendarManager.currentMonth)
    }

    var body: some View {
        HStack {
            Text(monthYearString)
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            HStack(spacing: 8) {
                Button(action: { calendarManager.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.glass)

                Button(action: { calendarManager.goToToday() }) {
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 11, height: 11)
                }
                .buttonStyle(.glass)

                Button(action: { calendarManager.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

