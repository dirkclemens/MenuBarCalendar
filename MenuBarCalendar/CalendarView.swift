//
// originally created by https://github.com/harryfliu and Claude Code
//    https://github.com/harryfliu/itsybitsycal/blob/main/Itsybitsycal/CalendarView.swift
//

import SwiftUI
import EventKit

struct CalendarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var hoveredDate: Date?

    private var nextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: calendarManager.currentMonth) ?? calendarManager.currentMonth
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with navigation
            CalendarHeaderView(calendarManager: calendarManager)

            Divider().frame(height: 1).background(.windowBackground)

            // Current month grid
            CalendarGridView(
                calendarManager: calendarManager,
                month: calendarManager.currentMonth,
                hoveredDate: $hoveredDate
            )
            
            Divider().frame(height: 1).background(.windowBackground)
            
//                // Next month label
//                MonthLabelView(month: nextMonth)
//
//                // Next month grid
//                CalendarGridView(
//                    calendarManager: calendarManager,
//                    month: nextMonth,
//                    hoveredDate: $hoveredDate
//                )
            
            Divider().frame(height: 1).background(.windowBackground)
            
            // Events list
            EventsListView(calendarManager: calendarManager)

            Divider().frame(height: 1).background(.windowBackground)

            // Bottom menu bar
            CalendarMenuBarView()
        }
        .padding(10)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .background(.windowBackground)
    }
}

struct CalendarMenuBarView: View {

    var body: some View {
        HStack {
            Button(action: { AppDelegate.instance.openSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(NSLocalizedString("SettingsMenuTitle", comment: ""))

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help(NSLocalizedString("QuitMenuTitle", comment: ""))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

struct MonthLabelView: View {
    let month: Date

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct CalendarHeaderView: View {
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
//            .contentShape(Rectangle())
            .contentShape(Circle())
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

struct WeekRow {
    let weekNumber: Int?
    let dates: [Date?]
}

struct CalendarGridView: View {
    @ObservedObject var calendarManager: CalendarManager
    let month: Date
    @Binding var hoveredDate: Date?

    private let weekNumberColumnWidth: CGFloat = 32
    private var weekdays: [String] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let rows = weekRows()

        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text(NSLocalizedString("WeekNumberHeader", comment: ""))
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.secondary)
                    .frame(width: weekNumberColumnWidth)

                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(index >= 5 ? .red.opacity(0.8) : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            VStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        WeekNumberView(number: week.weekNumber)
                            .frame(width: weekNumberColumnWidth)

                        ForEach(Array(week.dates.enumerated()), id: \.offset) { _, date in
                            if let date = date {
                                DayCell(
                                    date: date,
                                    calendarManager: calendarManager,
                                    isHovered: hoveredDate == date
                                )
                                .onHover { hovering in
                                    hoveredDate = hovering ? date : nil
                                }
                                .onTapGesture {
                                    calendarManager.selectedDate = date
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .frame(height: 32)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.vertical, 10)
    }

    private func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        // Compute leading empty days so the grid starts on Monday
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday + 5) % 7 // maps Mon->0, Tue->1, ..., Sun->6

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        // Add trailing days to complete the grid
        let trailingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingDays))

        return days
    }

    private func weekRows() -> [WeekRow] {
        let calendar = Calendar.current
        let dates = daysInMonth()

        var rows: [WeekRow] = []
        for chunkStart in stride(from: 0, to: dates.count, by: 7) {
            let end = min(chunkStart + 7, dates.count)
            let rowDates = Array(dates[chunkStart..<end])
            let weekNumber = rowDates.first(where: { $0 != nil }).flatMap {
                calendar.component(.weekOfYear, from: $0!)
            }
            rows.append(WeekRow(weekNumber: weekNumber, dates: rowDates))
        }

        return rows
    }
}

struct WeekNumberView: View {
    let number: Int?

    var body: some View {
        Text(number.map { "\($0)" } ?? "-")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
    }
}

struct DayCell: View {
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
        return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Today circle
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                }

                // Selection highlight
                if isSelected && !isToday {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 24, height: 22)
                }

                // Hover highlight
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

            // Event dots
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

struct EventDotsView: View {
    let colors: [CGColor]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .fill(Color(cgColor: colors[index]))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}
