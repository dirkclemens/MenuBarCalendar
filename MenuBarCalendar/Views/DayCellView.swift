//
// DayCellView.swift
//

import SwiftUI

struct DayCellView: View {
    let date: Date
    @ObservedObject var calendarManager: CalendarManager
    let isHovered: Bool

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: calendarManager.selectedDate)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: calendarManager.currentMonth, toGranularity: .month)
    }

    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                }

                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 24, height: 22)
                }

                if isHovered && !isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 24, height: 22)
                }

                Text(dayNumber)
                    .font(.system(size: 12))
                    .foregroundColor(textColor)
            }
            .frame(height: 22)

            EventDotsView(colors: calendarManager.eventDots(for: date))
        }
        .frame(height: 32)
    }

    private var textColor: Color {
        if isToday {
            return .white
        } else if !isCurrentMonth {
            return isWeekend ? Color.red.opacity(0.3) : .secondary.opacity(0.5)
        } else if isWeekend {
            return .red.opacity(0.8)
        } else {
            return .primary
        }
    }
}
