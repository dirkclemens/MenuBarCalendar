//
// originally created by https://github.com/harryfliu and Claude Code
//    https://github.com/harryfliu/itsybitsycal/blob/main/Itsybitsycal/CalendarManager.swift
//
//  tccutil reset Calendar
//

import Foundation
import EventKit
import SwiftUI
import Combine

// MARK: - Event Creation Enums

enum RecurrenceRule: String, CaseIterable {
    case never = "Never"
    case everyDay = "Every Day"
    case everyWeek = "Every Week"
    case everyTwoWeeks = "Every 2 Weeks"
    case everyMonth = "Every Month"
    case everyYear = "Every Year"
}

enum AlertOption: String, CaseIterable {
    case none = "None"
    case atTime = "At time of event"
    case fiveMinutes = "5 minutes before"
    case tenMinutes = "10 minutes before"
    case fifteenMinutes = "15 minutes before"
    case thirtyMinutes = "30 minutes before"
    case oneHour = "1 hour before"
    case twoHours = "2 hours before"
    case oneDay = "1 day before"
    case twoDays = "2 days before"
    case oneWeek = "1 week before"

    var alarmOffset: TimeInterval? {
        switch self {
        case .none: return nil
        case .atTime: return 0
        case .fiveMinutes: return -5 * 60
        case .tenMinutes: return -10 * 60
        case .fifteenMinutes: return -15 * 60
        case .thirtyMinutes: return -30 * 60
        case .oneHour: return -60 * 60
        case .twoHours: return -2 * 60 * 60
        case .oneDay: return -24 * 60 * 60
        case .twoDays: return -2 * 24 * 60 * 60
        case .oneWeek: return -7 * 24 * 60 * 60
        }
    }
}

// MARK: - Menu Bar Display

enum MenuBarDisplayMode: Int, CaseIterable {
    case dayOnly = 0
    case monthAndDay = 1
    case monthDayAndEvent = 2

    var description: String {
        switch self {
        case .dayOnly: return "Day only"
        case .monthAndDay: return "Month and day"
        case .monthDayAndEvent: return "Month, day, and event"
        }
    }

    var example: String {
        switch self {
        case .dayOnly: return "20"
        case .monthAndDay: return "Jan 20"
        case .monthDayAndEvent: return "Jan 20 - Meeting"
        }
    }
}

// MARK: - Datetime Pattern Presets

enum DatetimePatternPreset: Int, CaseIterable {
    case none = 0
    case timeOnly = 1
    case dayOfWeek = 2
    case dayOfWeekShort = 3
    case fullDate = 4
    case custom = 5

    var displayName: String {
        switch self {
        case .none: return "None"
        case .timeOnly: return "Time only"
        case .dayOfWeek: return "Day of week"
        case .dayOfWeekShort: return "Day (short)"
        case .fullDate: return "Full date"
        case .custom: return "Custom"
        }
    }

    var pattern: String {
        switch self {
        case .none: return ""
        case .timeOnly: return "h:mm a"
        case .dayOfWeek: return "EEEE"
        case .dayOfWeekShort: return "EEE"
        case .fullDate: return "EEE, MMM d"
        case .custom: return ""
        }
    }

    var example: String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return pattern.isEmpty ? "—" : formatter.string(from: Date())
    }
}

class CalendarManager: ObservableObject {
    let eventStore = EKEventStore()

    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false
    @Published var selectedDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var enabledCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
            fetchEvents()
        }
    }
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode")
        }
    }
    @Published var showDayNumberInIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDayNumberInIcon, forKey: "showDayNumberInIcon")
        }
    }
    @Published var showMonthInIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMonthInIcon, forKey: "showMonthInIcon")
        }
    }
    @Published var showDayOfWeekInIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDayOfWeekInIcon, forKey: "showDayOfWeekInIcon")
        }
    }
    @Published var datetimePatternPreset: DatetimePatternPreset {
        didSet {
            UserDefaults.standard.set(datetimePatternPreset.rawValue, forKey: "datetimePatternPreset")
        }
    }
    @Published var customDatetimePattern: String {
        didSet {
            UserDefaults.standard.set(customDatetimePattern, forKey: "customDatetimePattern")
        }
    }


    /// Trigger to notify views to scroll to current event (changes value to trigger)
    @Published var scrollToCurrentEventTrigger: UUID = UUID()

    init() {
        // Load saved calendar selections or default to all enabled
        if let saved = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") {
            enabledCalendarIDs = Set(saved)
        } else {
            enabledCalendarIDs = []
        }

        // Load saved menu bar display mode or default to dayOnly
        let savedMode = UserDefaults.standard.integer(forKey: "menuBarDisplayMode")
        menuBarDisplayMode = MenuBarDisplayMode(rawValue: savedMode) ?? .dayOnly

        // Load icon display options
        // Default showDayNumberInIcon to true for new installs
        if UserDefaults.standard.object(forKey: "showDayNumberInIcon") == nil {
            showDayNumberInIcon = true
        } else {
            showDayNumberInIcon = UserDefaults.standard.bool(forKey: "showDayNumberInIcon")
        }
        showMonthInIcon = UserDefaults.standard.bool(forKey: "showMonthInIcon")
        showDayOfWeekInIcon = UserDefaults.standard.bool(forKey: "showDayOfWeekInIcon")

        // Load datetime pattern settings
        let savedPatternPreset = UserDefaults.standard.integer(forKey: "datetimePatternPreset")
        datetimePatternPreset = DatetimePatternPreset(rawValue: savedPatternPreset) ?? .none
        customDatetimePattern = UserDefaults.standard.string(forKey: "customDatetimePattern") ?? "EEE h:mm a"

        handleAuthorization()
    }

    func menuBarTitle() -> String {
        let now = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)

        var components: [String] = []

        // Build date text based on checkbox settings
        if showDayOfWeekInIcon {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            components.append(formatter.string(from: now))
        }

        if showMonthInIcon {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            components.append(formatter.string(from: now))
        }

        if showDayNumberInIcon {
            components.append("\(day)")
        }

        // Add datetime pattern text if set
        let patternText = formattedDatetimePattern()
        if !patternText.isEmpty {
            if !components.isEmpty {
                components.append("•")
            }
            components.append(patternText)
        }

        // Add event if in that mode
        if menuBarDisplayMode == .monthDayAndEvent {
            if let currentEvent = currentOrNextEvent() {
                let eventTitle = currentEvent.title ?? "Event"
                let truncatedTitle = eventTitle.count > 12 ? String(eventTitle.prefix(12)) + "…" : eventTitle
                components.append("-")
                components.append(truncatedTitle)
            }
        }

        let result = components.joined(separator: " ")
        return result.isEmpty ? "" : " " + result
    }

    func formattedDatetimePattern() -> String {
        let pattern: String
        if datetimePatternPreset == .custom {
            pattern = customDatetimePattern
        } else {
            pattern = datetimePatternPreset.pattern
        }

        guard !pattern.isEmpty else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: Date())
    }

    func currentOrNextEvent() -> EKEvent? {
        let now = Date()
        let calendar = Calendar.current

        // Get today's events from enabled calendars
        let todayEvents = events.filter { event in
            calendar.isDateInToday(event.startDate) && isCalendarEnabled(event.calendar)
        }.sorted { $0.startDate < $1.startDate }

        // Find event that's currently happening or next upcoming
        for event in todayEvents {
            // Event is currently happening
            if event.startDate <= now && event.endDate > now {
                return event
            }
            // Event is upcoming today
            if event.startDate > now {
                return event
            }
        }

        return nil
    }

    func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        // If no calendars have been explicitly set, show all
        if enabledCalendarIDs.isEmpty {
            return true
        }
        return enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        // If toggling for the first time and set is empty, initialize with all calendars
        if enabledCalendarIDs.isEmpty {
            enabledCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
        }

        if enabledCalendarIDs.contains(calendar.calendarIdentifier) {
            enabledCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            enabledCalendarIDs.insert(calendar.calendarIdentifier)
        }
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                self?.updateAccess(granted: granted)
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                self?.updateAccess(granted: granted)
            }
        }
    }

    func refreshAuthorization() {
        handleAuthorization()
    }

    private func handleAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            requestAccess()
        case .authorized, .fullAccess:
            updateAccess(granted: true)
        default:
            updateAccess(granted: false)
        }
    }

    private func updateAccess(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hasAccess = granted
            if granted {
                self?.fetchCalendars()
                self?.fetchEvents()
            }
        }
    }

    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func fetchEvents() {
        guard hasAccess else { return }

        let calendar = Calendar.current

        // Get events for the visible month range (plus buffer for adjacent months)
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let startDate = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let endDate = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else {
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        events = eventStore.events(matching: predicate)
    }

    func events(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date) && isCalendarEnabled(event.calendar)
        }.sorted { $0.startDate < $1.startDate }
    }

    func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date) && isCalendarEnabled(event.calendar)
        }
    }

    func eventDots(for date: Date) -> [CGColor] {
        let dayEvents = events(for: date)
        var colors: [CGColor] = []
        var seenCalendars: Set<String> = []

        for event in dayEvents {
            if !seenCalendars.contains(event.calendar.calendarIdentifier) {
                colors.append(event.calendar.cgColor)
                seenCalendars.insert(event.calendar.calendarIdentifier)
                if colors.count >= 3 { break }
            }
        }
        return colors
    }

    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
        fetchEvents()
        // Trigger scroll to current event
        scrollToCurrentEventTrigger = UUID()
    }

    func previousMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newMonth
            fetchEvents()
        }
    }

    func nextMonth() {
        if let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newMonth
            fetchEvents()
        }
    }
}
