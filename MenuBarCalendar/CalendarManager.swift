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

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    let eventStore = EKEventStore()
    private var remindersFetchToken: UUID = UUID()

    @Published var events: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var hasAccess = false
    
    // Reminders
    @Published var reminders: [EKReminder] = []
    @Published var reminderLists: [EKCalendar] = []
    @Published var hasRemindersAccess = false
    @Published var enabledReminderListIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledReminderListIDs), forKey: "enabledReminderListIDs")
            fetchReminders()
        }
    }
    @Published var selectedDate: Date = Date() {
        didSet {
            refreshVisibleContent()
        }
    }
    @Published var currentMonth: Date = Date()
    @Published var enabledCalendarIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
            fetchEvents()
        }
    }
    /// Trigger to notify views to scroll to current event (changes value to trigger)
    @Published var scrollToCurrentEventTrigger: UUID = UUID()

    /// The current or next upcoming event today, for display in the menu bar label.
    @Published var nextEvent: EKEvent?

    /// Current date — updated at midnight so the menu bar icon redraws automatically.
    @Published var today: Date = Date()

    private func updateNextEvent() {
        let now = Date()
        let calendar = Calendar.current
        let showAllDay = UserDefaults.standard.bool(forKey: "showAllDayEventsInMenuBar")
        nextEvent = events
            .filter {
                isCalendarEnabled($0.calendar)
                && calendar.isDateInToday($0.startDate)
                && $0.endDate > now
                && (!$0.isAllDay || showAllDay)
            }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    func refreshNextEvent() {
        updateNextEvent()
    }

    init() {
        // Load saved calendar selections or default to all enabled
        if let saved = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") {
            enabledCalendarIDs = Set(saved)
        } else {
            enabledCalendarIDs = []
        }
        
        // Load saved reminder list selections
        if let savedReminders = UserDefaults.standard.stringArray(forKey: "enabledReminderListIDs") {
            enabledReminderListIDs = Set(savedReminders)
        } else {
            enabledReminderListIDs = []
        }

        handleAuthorization()
        handleRemindersAuthorization()
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

    func isReminderListEnabled(_ calendar: EKCalendar) -> Bool {
        if enabledReminderListIDs.isEmpty {
            return true
        }
        return enabledReminderListIDs.contains(calendar.calendarIdentifier)
    }

    func toggleReminderList(_ calendar: EKCalendar) {
        if enabledReminderListIDs.isEmpty {
            enabledReminderListIDs = Set(reminderLists.map { $0.calendarIdentifier })
        }

        if enabledReminderListIDs.contains(calendar.calendarIdentifier) {
            enabledReminderListIDs.remove(calendar.calendarIdentifier)
        } else {
            enabledReminderListIDs.insert(calendar.calendarIdentifier)
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
        handleRemindersAuthorization()
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

    // MARK: - Reminders Authorization

    func requestRemindersAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                self?.updateRemindersAccess(granted: granted)
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                self?.updateRemindersAccess(granted: granted)
            }
        }
    }

    private func handleRemindersAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .notDetermined:
            requestRemindersAccess()
        case .authorized, .fullAccess:
            updateRemindersAccess(granted: true)
        default:
            updateRemindersAccess(granted: false)
        }
    }

    private func updateRemindersAccess(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hasRemindersAccess = granted
            if granted {
                self?.fetchReminderLists()
                self?.refreshVisibleContent()
            }
        }
    }

    func fetchReminderLists() {
        reminderLists = eventStore.calendars(for: .reminder)
    }

    func fetchReminders() {
        guard hasRemindersAccess else { return }

        let (start, end) = contentFetchRange()

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: start,
            ending: end,
            calendars: selectedReminderLists()
        )

        let fetchToken = UUID()
        remindersFetchToken = fetchToken

        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            DispatchQueue.main.async {
                guard let self, self.remindersFetchToken == fetchToken else { return }

                self.reminders = (fetchedReminders ?? []).filter { reminder in
                    guard let cal = reminder.calendar else { return false }
                    return self.isReminderListEnabled(cal)
                }.sorted { r1, r2 in
                    let d1 = r1.dueDateComponents?.date ?? Date.distantFuture
                    let d2 = r2.dueDateComponents?.date ?? Date.distantFuture
                    return d1 < d2
                }
            }
        }
    }

    func reminders(for date: Date) -> [EKReminder] {
        let calendar = Calendar.current
        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return calendar.isDate(dueDate, inSameDayAs: date)
        }
    }

    private func updateAccess(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.hasAccess = granted
            if granted {
                self?.refreshToday()
                self?.fetchCalendars()
                self?.refreshVisibleContent()
            }
        }
    }

    /// Reset selected date and current month to today — call on every activation.
    func refreshToday() {
        let now = Date()
        let calendar = Calendar.current
        NSLog("refreshToday fired at \(now)")
        today = now
        if !calendar.isDateInToday(selectedDate) {
            selectedDate = now
        }
        if !calendar.isDate(currentMonth, equalTo: now, toGranularity: .month) {
            currentMonth = now
        }
    }

    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
    }

    func fetchEvents() {
        guard hasAccess else { return }

        let (startDate, fetchEnd) = contentFetchRange()

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: fetchEnd,
            calendars: selectedEventCalendars()
        )
        events = eventStore.events(matching: predicate)
        updateNextEvent()
    }

    func events(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: date) && isCalendarEnabled(event.calendar)
        }.sorted { $0.startDate < $1.startDate }
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

    func reminderDots(for date: Date) -> [CGColor] {
        let dayReminders = reminders(for: date)
        var colors: [CGColor] = []
        var seenLists: Set<String> = []

        for reminder in dayReminders {
            guard let list = reminder.calendar else { continue }
            if !seenLists.contains(list.calendarIdentifier) {
                colors.append(list.cgColor)
                seenLists.insert(list.calendarIdentifier)
                if colors.count >= 3 { break }
            }
        }
        return colors
    }

    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
        // Trigger scroll to current event
        scrollToCurrentEventTrigger = UUID()
    }

    func previousMonth() {
        moveMonth(by: -1)
    }

    func nextMonth() {
        moveMonth(by: 1)
    }

    private func moveMonth(by value: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }

        currentMonth = newMonth

        let selectedDay = calendar.component(.day, from: selectedDate)
        let newMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: newMonth)) ?? newMonth
        let dayRange = calendar.range(of: .day, in: .month, for: newMonthStart) ?? 1..<32
        let clampedDay = min(selectedDay, dayRange.count)

        if let syncedSelection = calendar.date(byAdding: .day, value: clampedDay - 1, to: newMonthStart) {
            selectedDate = syncedSelection
        }

        scrollToCurrentEventTrigger = UUID()
    }

    private func refreshVisibleContent() {
        if hasAccess {
            fetchEvents()
        }
        if hasRemindersAccess {
            fetchReminders()
        }
    }

    private func contentFetchRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthFetchStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let monthFetchEnd = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else {
            let start = calendar.startOfDay(for: selectedDate)
            let fallbackEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return (start, fallbackEnd)
        }

        let configuredRange = UserDefaults.standard.integer(forKey: "eventsListDaysRange")
        let days = configuredRange > 0 ? configuredRange : 7
        let listStart = calendar.startOfDay(for: selectedDate)
        let listEnd = calendar.date(byAdding: .day, value: days, to: listStart) ?? monthFetchEnd

        return (monthFetchStart, max(monthFetchEnd, listEnd))
    }

    private func selectedEventCalendars() -> [EKCalendar]? {
        guard !enabledCalendarIDs.isEmpty else { return nil }
        return calendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
    }

    private func selectedReminderLists() -> [EKCalendar]? {
        guard !enabledReminderListIDs.isEmpty else { return nil }
        return reminderLists.filter { enabledReminderListIDs.contains($0.calendarIdentifier) }
    }
}
