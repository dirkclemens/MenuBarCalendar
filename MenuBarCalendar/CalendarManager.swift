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
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Defaults keys

    private enum Keys {
        static let disabledCalendarIDs = "disabledCalendarIDs"
        static let disabledReminderListIDs = "disabledReminderListIDs"
        // Legacy keys (whitelist, where an empty set meant "all") — migrated on first launch.
        static let legacyEnabledCalendarIDs = "enabledCalendarIDs"
        static let legacyEnabledReminderListIDs = "enabledReminderListIDs"
        static let eventsListDaysRange = "eventsListDaysRange"
        static let showAllDayEventsInMenuBar = "showAllDayEventsInMenuBar"
    }

    // MARK: - Published state

    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var hasAccess = false

    // Reminders
    @Published private(set) var reminders: [EKReminder] = []
    @Published private(set) var reminderLists: [EKCalendar] = []
    @Published private(set) var hasRemindersAccess = false

    /// Calendars the user switched off. Stored as a blacklist so that calendars
    /// added later show up automatically and switching off *all* calendars works.
    @Published private(set) var disabledCalendarIDs: Set<String>
    @Published private(set) var disabledReminderListIDs: Set<String>

    @Published var selectedDate: Date = Date() {
        didSet { refreshVisibleContent(force: false) }
    }
    @Published var currentMonth: Date = Date() {
        didSet { refreshVisibleContent(force: false) }
    }

    /// Trigger to notify views to scroll to current event (changes value to trigger)
    @Published var scrollToCurrentEventTrigger: UUID = UUID()

    /// The current or next upcoming event today, for display in the menu bar label.
    @Published private(set) var nextEvent: EKEvent?

    /// Current date — updated when the day changes so the menu bar icon redraws automatically.
    @Published private(set) var today: Date = Date()

    // MARK: - Derived caches (rebuilt on every fetch)

    /// Events indexed by start of day. Multi-day events appear on every day they cover.
    private var eventsByDay: [Date: [EKEvent]] = [:]
    private var remindersByDay: [Date: [EKReminder]] = [:]
    /// Date ranges the current `events` / `reminders` cover — used to skip redundant fetches.
    private var loadedEventRange: DateInterval?
    private var loadedReminderRange: DateInterval?

    private var legacyEnabledCalendarIDs: Set<String>?
    private var legacyEnabledReminderListIDs: Set<String>?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        disabledCalendarIDs = Set(defaults.stringArray(forKey: Keys.disabledCalendarIDs) ?? [])
        disabledReminderListIDs = Set(defaults.stringArray(forKey: Keys.disabledReminderListIDs) ?? [])
        legacyEnabledCalendarIDs = defaults.stringArray(forKey: Keys.legacyEnabledCalendarIDs).map(Set.init)
        legacyEnabledReminderListIDs = defaults.stringArray(forKey: Keys.legacyEnabledReminderListIDs).map(Set.init)

        // Refetch whenever calendar data changes (other apps, iCloud sync, …).
        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: eventStore)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.eventStoreDidChange() }
            .store(in: &cancellables)

        // Unit tests run inside the app; don't trigger permission prompts there.
        guard !AppEnvironment.isRunningTests else { return }
        handleAuthorization()
        handleRemindersAuthorization()
    }

    private func eventStoreDidChange() {
        if hasAccess { fetchCalendars() }
        if hasRemindersAccess { fetchReminderLists() }
        refreshVisibleContent(force: true)
    }

    // MARK: - Calendar / list selection

    func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        !disabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        disabledCalendarIDs.formSymmetricDifference([calendar.calendarIdentifier])
        UserDefaults.standard.set(Array(disabledCalendarIDs), forKey: Keys.disabledCalendarIDs)
        fetchEvents()
    }

    func isReminderListEnabled(_ calendar: EKCalendar) -> Bool {
        !disabledReminderListIDs.contains(calendar.calendarIdentifier)
    }

    func toggleReminderList(_ calendar: EKCalendar) {
        disabledReminderListIDs.formSymmetricDifference([calendar.calendarIdentifier])
        UserDefaults.standard.set(Array(disabledReminderListIDs), forKey: Keys.disabledReminderListIDs)
        fetchReminders()
    }

    // MARK: - Authorization (events)

    func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            self?.updateAccess(granted: granted)
        }
    }

    func refreshAuthorization() {
        handleAuthorization()
        handleRemindersAuthorization()
    }

    private func handleAuthorization() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            requestAccess()
        case .fullAccess:
            updateAccess(granted: true)
        default:
            updateAccess(granted: false)
        }
    }

    private func updateAccess(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hasAccess != granted { self.hasAccess = granted }
            if granted {
                self.refreshToday()
                self.fetchCalendars()
                self.fetchEvents()
            } else {
                self.clearEvents()
            }
        }
    }

    // MARK: - Authorization (reminders)

    func requestRemindersAccess() {
        eventStore.requestFullAccessToReminders { [weak self] granted, _ in
            self?.updateRemindersAccess(granted: granted)
        }
    }

    private func handleRemindersAuthorization() {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            requestRemindersAccess()
        case .fullAccess:
            updateRemindersAccess(granted: true)
        default:
            updateRemindersAccess(granted: false)
        }
    }

    private func updateRemindersAccess(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.hasRemindersAccess != granted { self.hasRemindersAccess = granted }
            if granted {
                self.fetchReminderLists()
                self.fetchReminders()
            } else {
                self.setReminders([])
                self.loadedReminderRange = nil
            }
        }
    }

    // MARK: - Fetching

    func fetchCalendars() {
        calendars = eventStore.calendars(for: .event)
        if let legacy = legacyEnabledCalendarIDs {
            disabledCalendarIDs = Self.migrate(legacyEnabled: legacy, all: calendars,
                                               legacyKey: Keys.legacyEnabledCalendarIDs,
                                               newKey: Keys.disabledCalendarIDs)
            legacyEnabledCalendarIDs = nil
        }
    }

    func fetchReminderLists() {
        reminderLists = eventStore.calendars(for: .reminder)
        if let legacy = legacyEnabledReminderListIDs {
            disabledReminderListIDs = Self.migrate(legacyEnabled: legacy, all: reminderLists,
                                                   legacyKey: Keys.legacyEnabledReminderListIDs,
                                                   newKey: Keys.disabledReminderListIDs)
            legacyEnabledReminderListIDs = nil
        }
    }

    private static func migrate(legacyEnabled: Set<String>, all: [EKCalendar],
                                legacyKey: String, newKey: String) -> Set<String> {
        let disabled = disabledIDs(fromLegacyEnabled: legacyEnabled, allIDs: all.map(\.calendarIdentifier))
        UserDefaults.standard.set(Array(disabled), forKey: newKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return disabled
    }

    /// Converts the old whitelist (empty = all enabled) into the new blacklist.
    nonisolated static func disabledIDs(fromLegacyEnabled legacyEnabled: Set<String>, allIDs: [String]) -> Set<String> {
        legacyEnabled.isEmpty ? [] : Set(allIDs).subtracting(legacyEnabled)
    }

    /// Re-reads events and reminders. With `force == false` the fetch is skipped
    /// when the already loaded data covers the range needed for the current view.
    func refreshVisibleContent(force: Bool = true) {
        let range = contentFetchRange()
        if hasAccess, force || !(loadedEventRange?.covers(range) ?? false) {
            fetchEvents()
        }
        if hasRemindersAccess, force || !(loadedReminderRange?.covers(range) ?? false) {
            fetchReminders()
        }
    }

    func fetchEvents() {
        guard hasAccess else { return }

        let range = contentFetchRange()
        let enabledCalendars = calendars.filter(isCalendarEnabled)

        // An empty calendar list would make EventKit search *all* calendars.
        guard !enabledCalendars.isEmpty else {
            clearEvents()
            loadedEventRange = range
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: disabledCalendarIDs.isEmpty ? nil : enabledCalendars
        )
        let fetched = eventStore.events(matching: predicate)
            .filter { isCalendarEnabled($0.calendar) }
            .sorted(by: Self.eventOrder)

        eventsByDay = Self.indexByDay(fetched, within: range)
        loadedEventRange = range
        events = fetched
        updateNextEvent()
    }

    func fetchReminders() {
        guard hasRemindersAccess else { return }

        let range = contentFetchRange()
        let enabledLists = reminderLists.filter(isReminderListEnabled)
        let fetchToken = UUID()
        remindersFetchToken = fetchToken

        guard !enabledLists.isEmpty else {
            setReminders([])
            loadedReminderRange = range
            return
        }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: range.start,
            ending: range.end,
            calendars: disabledReminderListIDs.isEmpty ? nil : enabledLists
        )

        eventStore.fetchReminders(matching: predicate) { [weak self] fetchedReminders in
            DispatchQueue.main.async {
                guard let self, self.remindersFetchToken == fetchToken else { return }

                let sorted = (fetchedReminders ?? [])
                    .filter { reminder in
                        guard let list = reminder.calendar else { return false }
                        return self.isReminderListEnabled(list)
                    }
                    .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

                self.loadedReminderRange = range
                self.setReminders(sorted)
            }
        }
    }

    private func setReminders(_ sorted: [EKReminder]) {
        let calendar = Calendar.current
        var byDay: [Date: [EKReminder]] = [:]
        for reminder in sorted {
            guard let due = reminder.dueDate else { continue }
            byDay[calendar.startOfDay(for: due), default: []].append(reminder)
        }
        remindersByDay = byDay
        reminders = sorted
    }

    /// Marks a reminder as completed in the Reminders database and removes it
    /// from the list right away. Returns false if saving failed.
    @discardableResult
    func completeReminder(_ reminder: EKReminder) -> Bool {
        reminder.isCompleted = true
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            reminder.isCompleted = false
            NSLog("Failed to complete reminder: \(error.localizedDescription)")
            return false
        }
        setReminders(reminders.filter { $0.calendarItemIdentifier != reminder.calendarItemIdentifier })
        return true
    }

    private func clearEvents() {
        events = []
        eventsByDay = [:]
        loadedEventRange = nil
        updateNextEvent()
    }

    // MARK: - Queries used by the views

    func events(for date: Date) -> [EKEvent] {
        eventsByDay[Calendar.current.startOfDay(for: date)] ?? []
    }

    func reminders(for date: Date) -> [EKReminder] {
        remindersByDay[Calendar.current.startOfDay(for: date)] ?? []
    }

    func eventDots(for date: Date) -> [CGColor] {
        Self.uniqueColors(of: events(for: date).map(\.calendar))
    }

    func reminderDots(for date: Date) -> [CGColor] {
        Self.uniqueColors(of: reminders(for: date).compactMap(\.calendar))
    }

    private static func uniqueColors(of calendars: [EKCalendar], limit: Int = 3) -> [CGColor] {
        var colors: [CGColor] = []
        var seen: Set<String> = []
        for calendar in calendars where seen.insert(calendar.calendarIdentifier).inserted {
            colors.append(calendar.cgColor)
            if colors.count >= limit { break }
        }
        return colors
    }

    // MARK: - Next event (menu bar label)

    func refreshNextEvent() {
        updateNextEvent()
    }

    private func updateNextEvent() {
        let now = Date()
        let calendar = Calendar.current
        let showAllDay = UserDefaults.standard.bool(forKey: Keys.showAllDayEventsInMenuBar)
        let candidate = events(for: now).first {
            calendar.isDateInToday($0.startDate)
            && $0.endDate > now
            && (!$0.isAllDay || showAllDay)
        }
        // Only publish real changes — this runs every minute and every publish
        // re-renders the menu bar label and the open popover.
        if !Self.isSameEvent(nextEvent, candidate) {
            nextEvent = candidate
        }
    }

    private static func isSameEvent(_ a: EKEvent?, _ b: EKEvent?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?):
            return a.eventIdentifier == b.eventIdentifier
                && a.startDate == b.startDate
                && a.endDate == b.endDate
                && a.title == b.title
                && a.calendar.calendarIdentifier == b.calendar.calendarIdentifier
        default: return false
        }
    }

    // MARK: - Navigation

    /// Reset selected date and current month to today when the day has changed.
    func refreshToday() {
        let now = Date()
        let calendar = Calendar.current
        if !calendar.isDate(today, inSameDayAs: now) {
            today = now
        }
        if !calendar.isDate(currentMonth, equalTo: now, toGranularity: .month) {
            currentMonth = now
        }
        if !calendar.isDateInToday(selectedDate) {
            selectedDate = now
        }
        updateNextEvent()
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

    // MARK: - Helpers

    private func contentFetchRange() -> DateInterval {
        let calendar = Calendar.current

        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let monthFetchStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth),
              let monthFetchEnd = calendar.date(byAdding: .month, value: 2, to: startOfMonth) else {
            let start = calendar.startOfDay(for: selectedDate)
            let fallbackEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: fallbackEnd)
        }

        let configuredRange = UserDefaults.standard.integer(forKey: Keys.eventsListDaysRange)
        let days = configuredRange > 0 ? configuredRange : 7
        let listStart = calendar.startOfDay(for: selectedDate)
        let listEnd = calendar.date(byAdding: .day, value: days, to: listStart) ?? monthFetchEnd

        return DateInterval(start: min(monthFetchStart, listStart), end: max(monthFetchEnd, listEnd))
    }

    nonisolated private static func eventOrder(_ a: EKEvent, _ b: EKEvent) -> Bool {
        if a.isAllDay != b.isAllDay { return a.isAllDay }
        if a.startDate != b.startDate { return a.startDate < b.startDate }
        return (a.title ?? "") < (b.title ?? "")
    }

    /// Builds a start-of-day → events lookup. Events spanning several days are
    /// added to each covered day (clamped to `range`).
    nonisolated static func indexByDay(_ events: [EKEvent], within range: DateInterval) -> [Date: [EKEvent]] {
        let calendar = Calendar.current
        let rangeFirstDay = calendar.startOfDay(for: range.start)
        let rangeLastDay = calendar.startOfDay(for: range.end)
        var index: [Date: [EKEvent]] = [:]

        for event in events {
            guard let start = event.startDate, let end = event.endDate else { continue }
            // The end date is exclusive: an event ending at 00:00 does not cover that day.
            let lastInstant = end > start ? end.addingTimeInterval(-1) : start
            var day = max(calendar.startOfDay(for: start), rangeFirstDay)
            let lastDay = min(calendar.startOfDay(for: lastInstant), rangeLastDay)

            while day <= lastDay {
                index[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return index
    }
}

extension EKReminder {
    /// Due date resolved with the current calendar. Safer than `dueDateComponents.date`,
    /// which returns nil whenever the components carry no calendar.
    var dueDate: Date? {
        dueDateComponents.flatMap { Calendar.current.date(from: $0) }
    }

    /// False for reminders that are due on a day without a specific time.
    var hasDueTime: Bool {
        dueDateComponents?.hour != nil
    }
}

private extension DateInterval {
    func covers(_ other: DateInterval) -> Bool {
        start <= other.start && end >= other.end
    }
}
