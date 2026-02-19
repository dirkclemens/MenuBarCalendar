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
        }
        .padding(10)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .background(.windowBackground)
    }
}

struct MonthLabelView: View {
    let month: Date

    private var label: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
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
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: calendarManager.currentMonth)
    }

    var body: some View {
        HStack {
            Text(monthYearString)
                .font(.system(size: 13, weight: .semibold))

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
                        .frame(width: 6, height: 6)
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
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

struct CalendarGridView: View {
    @ObservedObject var calendarManager: CalendarManager
    let month: Date
    @Binding var hoveredDate: Date?

    // Start week on Monday
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 4) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, day in
                    Text(String(day.prefix(1)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(index >= 5 ? .red.opacity(0.8) : .secondary) // Sat/Sun are now indexes 5 and 6
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            // Calendar days
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { index, date in
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
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .padding(.bottom, 8)
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

struct ToolbarView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
//            Button(action: { AppDelegate.instance.showAddEventPanel() }) {
//                Image(systemName: "plus")
//                    .font(.system(size: 13))
//            }
//            .buttonStyle(ToolbarButtonStyle())
//
//            Spacer()

            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.internetaccounts") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(ToolbarButtonStyle())

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

// MARK: - Menu Bar Appearance Section

struct MenuBarAppearanceSection: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var showPatternHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MENU BAR")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {

                // Date Display Options
                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(
                        title: "Show day number",
                        isOn: $calendarManager.showDayNumberInIcon
                    )
                    ToggleRow(
                        title: "Show month",
                        isOn: $calendarManager.showMonthInIcon
                    )
                    ToggleRow(
                        title: "Show day of week",
                        isOn: $calendarManager.showDayOfWeekInIcon
                    )
                }

                Divider()
                    .padding(.horizontal, 10)

                // Datetime Pattern section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Text Display")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: { showPatternHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPatternHelp) {
                            DatetimePatternHelpView()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // Pattern presets
                    DatetimePatternPicker(
                        selectedPreset: $calendarManager.datetimePatternPreset,
                        customPattern: $calendarManager.customDatetimePattern
                    )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 10)

                // Show event option
                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(
                        title: "Show current/next event",
                        isOn: Binding(
                            get: { calendarManager.menuBarDisplayMode == .monthDayAndEvent },
                            set: { calendarManager.menuBarDisplayMode = $0 ? .monthDayAndEvent : .dayOnly }
                        )
                    )
                }

                // Preview
                MenuBarPreview(calendarManager: calendarManager)
                    .padding(10)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 13))
                .foregroundColor(isOn ? .accentColor : .secondary)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            isOn.toggle()
        }
    }
}

struct DatetimePatternPicker: View {
    @Binding var selectedPreset: DatetimePatternPreset
    @Binding var customPattern: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(DatetimePatternPreset.allCases, id: \.rawValue) { preset in
                DatetimePresetRow(
                    preset: preset,
                    isSelected: selectedPreset == preset,
                    action: { selectedPreset = preset }
                )
            }

            // Custom pattern input (only show if custom is selected)
            if selectedPreset == .custom {
                HStack {
                    TextField("Pattern (e.g. EEE h:mm a)", text: $customPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))

                    Text(formattedCustomPattern())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 60)
                }
                .padding(.top, 4)
            }
        }
    }

    private func formattedCustomPattern() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = customPattern
        return formatter.string(from: Date())
    }
}

struct DatetimePresetRow: View {
    let preset: DatetimePatternPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(preset.displayName)
                .font(.system(size: 11))
                .foregroundColor(.primary)

            Spacer()

            if preset != .custom && preset != .none {
                Text(preset.example)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

struct DatetimePatternHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date & Time Patterns")
                .font(.system(size: 12, weight: .semibold))

            Text("Common patterns:")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                PatternHelpRow(pattern: "EEE", description: "Day of week (Mon)")
                PatternHelpRow(pattern: "EEEE", description: "Full day (Monday)")
                PatternHelpRow(pattern: "MMM", description: "Month (Jan)")
                PatternHelpRow(pattern: "d", description: "Day number (20)")
                PatternHelpRow(pattern: "h:mm a", description: "Time (3:45 PM)")
                PatternHelpRow(pattern: "HH:mm", description: "24h time (15:45)")
            }

            Text("Combine patterns freely!")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(12)
        .frame(width: 200)
    }
}

struct PatternHelpRow: View {
    let pattern: String
    let description: String

    var body: some View {
        HStack {
            Text(pattern)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.accentColor)
                .frame(width: 60, alignment: .leading)

            Text(description)
                .font(.system(size: 10))
                .foregroundColor(.primary)
        }
    }
}

struct MenuBarPreview: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                // Title preview
                Text(calendarManager.menuBarTitle().trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(4)
        }
    }
}

struct CalendarsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var groupedCalendars: [(String, [EKCalendar])] {
        var groups: [String: [EKCalendar]] = [:]

        for calendar in calendarManager.calendars {
            let sourceName = calendar.source.title
            if groups[sourceName] == nil {
                groups[sourceName] = []
            }
            groups[sourceName]?.append(calendar)
        }

        // Sort groups by name, but put iCloud first if present
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            CalendarToggleRow(
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

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 12, height: 12)

                Text(calendar.title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
