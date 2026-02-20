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

            HStack(spacing: 4) {
                Button(action: { calendarManager.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NavButtonStyle())

                Button(action: { calendarManager.goToToday() }) {
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(NavButtonStyle())

                Button(action: { calendarManager.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(NavButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct NavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 20, height: 20)
            .contentShape(Circle())
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}
