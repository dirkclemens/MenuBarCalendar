//
//  CalendarGridView.swift
//

import SwiftUI

struct WeekRow {
    let weekNumber: Int?
    let dates: [Date?]
}

struct CalendarGridView: View {
    @ObservedObject var calendarManager: CalendarManager
    let month: Date
    @Binding var hoveredDate: Date?
    @AppStorage("showReminders") private var showReminders = true

    private let weekNumberColumnWidth: CGFloat = 48
    private var weekdays: [String] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var body: some View {
        let rows = Self.weekRows(for: month)

        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
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
                                DayCellView(
                                    date: date,
                                    calendarManager: calendarManager,
                                    isHovered: hoveredDate == date,
                                    showReminders: showReminders
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

    /// Days of `month`, padded with nil so the first column is Monday and every row has 7 entries.
    static func daysInMonth(_ month: Date) -> [Date?] {
        let calendar = Calendar.current

        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyDays)

        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }

        let trailingDays = (7 - (days.count % 7)) % 7
        days.append(contentsOf: Array(repeating: nil, count: trailingDays))

        return days
    }

    static func weekRows(for month: Date) -> [WeekRow] {
        // ISO 8601 (Monday-first, week containing Jan 4th = week 1) matches the grid layout
        // regardless of the user's region; Calendar.current would give US week numbers in en_US.
        let calendar = Calendar(identifier: .iso8601)
        let dates = daysInMonth(month)

        var rows: [WeekRow] = []
        for chunkStart in stride(from: 0, to: dates.count, by: 7) {
            let end = min(chunkStart + 7, dates.count)
            let rowDates = Array(dates[chunkStart..<end])
            let weekNumber = rowDates.compactMap { $0 }.first.map {
                calendar.component(.weekOfYear, from: $0)
            }
            rows.append(WeekRow(weekNumber: weekNumber, dates: rowDates))
        }

        return rows
    }
}
