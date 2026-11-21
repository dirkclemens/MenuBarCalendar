//
//  MenuBarCalendarTests.swift
//  MenuBarCalendarTests
//

import Testing
import Foundation
import EventKit
@testable import MenuBarCalendar

// MARK: - Helpers

/// Creating EKEvent / EKReminder objects needs a store, but no calendar permission.
private let store = EKEventStore()
private let calendar = Calendar.current

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

private func event(_ start: Date, _ end: Date, allDay: Bool = false, title: String = "Test") -> EKEvent {
    let event = EKEvent(eventStore: store)
    event.title = title
    event.startDate = start
    event.endDate = end
    event.isAllDay = allDay
    return event
}

private let november2026 = DateInterval(start: date(2026, 10, 1), end: date(2027, 1, 1))

// MARK: - Day index

@MainActor
@Suite("Events by day")
struct EventIndexTests {
    @Test func timedEventAppearsOnItsDayOnly() {
        let meeting = event(date(2026, 11, 21, 10), date(2026, 11, 21, 11))
        let index = CalendarManager.indexByDay([meeting], within: november2026)

        #expect(index.count == 1)
        #expect(index[date(2026, 11, 21)]?.first === meeting)
    }

    @Test func multiDayEventAppearsOnEveryDay() {
        // All-day events from EventKit end at 23:59:59 of their last day.
        let vacation = event(date(2026, 11, 20), date(2026, 11, 23, 23, 59), allDay: true)
        let index = CalendarManager.indexByDay([vacation], within: november2026)

        let days = index.keys.sorted()
        #expect(days == [date(2026, 11, 20), date(2026, 11, 21), date(2026, 11, 22), date(2026, 11, 23)])
    }

    @Test func eventEndingAtMidnightDoesNotSpillIntoNextDay() {
        let evening = event(date(2026, 11, 21, 20), date(2026, 11, 22))
        let index = CalendarManager.indexByDay([evening], within: november2026)

        #expect(index.keys.sorted() == [date(2026, 11, 21)])
    }

    @Test func overnightEventCoversBothDays() {
        let party = event(date(2026, 11, 21, 22), date(2026, 11, 22, 2))
        let index = CalendarManager.indexByDay([party], within: november2026)

        #expect(index.keys.sorted() == [date(2026, 11, 21), date(2026, 11, 22)])
    }

    @Test func zeroLengthEventIsIndexed() {
        let reminderLike = event(date(2026, 11, 21, 9), date(2026, 11, 21, 9))
        let index = CalendarManager.indexByDay([reminderLike], within: november2026)

        #expect(index.keys.sorted() == [date(2026, 11, 21)])
    }

    @Test func longEventIsClampedToFetchRange() {
        let yearLong = event(date(2026, 1, 1), date(2027, 12, 31))
        let index = CalendarManager.indexByDay([yearLong], within: november2026)

        #expect(index.keys.min() == date(2026, 10, 1))
        #expect(index.keys.max() == date(2027, 1, 1))
    }

    @Test func recurringOccurrencesGetDistinctRowIDs() {
        // Occurrences of a recurring event share one eventIdentifier; row ids must still differ.
        let morning = event(date(2026, 11, 21, 9), date(2026, 11, 21, 10))
        let evening = event(date(2026, 11, 21, 18), date(2026, 11, 21, 19))
        let day = date(2026, 11, 21)

        #expect(EventsListView.rowID(day: day, event: morning) != EventsListView.rowID(day: day, event: evening))
        #expect(EventsListView.rowID(day: day, event: morning)
                != EventsListView.rowID(day: date(2026, 11, 22), event: morning))
    }
}

// MARK: - Calendar selection migration

@Suite("Calendar selection migration")
struct SelectionMigrationTests {
    @Test func emptyLegacyWhitelistMeansAllEnabled() {
        #expect(CalendarManager.disabledIDs(fromLegacyEnabled: [], allIDs: ["a", "b"]).isEmpty)
    }

    @Test func legacyWhitelistBecomesBlacklist() {
        let disabled = CalendarManager.disabledIDs(fromLegacyEnabled: ["a"], allIDs: ["a", "b", "c"])
        #expect(disabled == ["b", "c"])
    }

    @Test func unknownLegacyIDsAreIgnored() {
        let disabled = CalendarManager.disabledIDs(fromLegacyEnabled: ["gone"], allIDs: ["a"])
        #expect(disabled == ["a"])
    }
}

// MARK: - Month grid

@MainActor
@Suite("Month grid")
struct MonthGridTests {
    @Test func gridStartsOnMondayAndHasFullRows() {
        // 1 November 2026 is a Sunday → six empty cells before it.
        let days = CalendarGridView.daysInMonth(date(2026, 11, 15))

        #expect(days.count % 7 == 0)
        #expect(days.prefix(6).allSatisfy { $0 == nil })
        #expect(days[6] == date(2026, 11, 1))
        #expect(days.compactMap { $0 }.count == 30)
    }

    @Test func monthStartingOnMondayHasNoLeadingGap() {
        // 1 June 2026 is a Monday.
        let days = CalendarGridView.daysInMonth(date(2026, 6, 10))
        #expect(days.first == date(2026, 6, 1))
    }

    @Test func weekNumbersFollowISO8601() {
        let rows = CalendarGridView.weekRows(for: date(2026, 11, 1))
        // 26 Oct – 1 Nov 2026 is ISO week 44, then 45 … 49.
        #expect(rows.map(\.weekNumber) == [44, 45, 46, 47, 48, 49])
    }

    @Test func weekNumberAtYearBoundary() {
        // 1 January 2027 is a Friday → still ISO week 53 of 2026.
        let rows = CalendarGridView.weekRows(for: date(2027, 1, 1))
        #expect(rows.first?.weekNumber == 53)
        #expect(rows.dropFirst().first?.weekNumber == 1)
    }
}

// MARK: - Reminders

@MainActor
@Suite("Reminder due dates")
struct ReminderDueDateTests {
    @Test func dueDateWithTime() {
        let reminder = EKReminder(eventStore: store)
        reminder.dueDateComponents = DateComponents(year: 2026, month: 11, day: 21, hour: 14, minute: 30)

        #expect(reminder.dueDate == date(2026, 11, 21, 14, 30))
        #expect(reminder.hasDueTime)
    }

    @Test func allDayReminderHasNoTime() {
        let reminder = EKReminder(eventStore: store)
        reminder.dueDateComponents = DateComponents(year: 2026, month: 11, day: 21)

        #expect(reminder.dueDate == date(2026, 11, 21))
        #expect(!reminder.hasDueTime)
    }

    @Test func reminderWithoutDueDate() {
        let reminder = EKReminder(eventStore: store)
        #expect(reminder.dueDate == nil)
        #expect(!reminder.hasDueTime)
    }
}

// MARK: - Update check

@MainActor
@Suite("Update check")
struct UpdateCheckTests {
    @Test(arguments: [
        ("1.0.2", "1.0.1", true),
        ("1.0.10", "1.0.9", true),
        ("2.0", "1.9.9", true),
        ("1.0.1", "1.0.1", false),
        ("1.0.0", "1.0.1", false),
        ("1.0", "1.0.0", false),
    ])
    func versionComparison(candidate: String, current: String, newer: Bool) {
        #expect(UpdateChecker.isVersion(candidate, newerThan: current) == newer)
    }

    private func response(_ json: String) throws -> UpdateCheckResponse {
        try JSONDecoder().decode(UpdateCheckResponse.self, from: Data(json.utf8))
    }

    @Test func newerVersionIsReported() throws {
        let result = try response("""
            {"latest_version": "1.1.0", "update_available": true, "download_url": "https://example.com/app.dmg"}
            """)
        let update = UpdateChecker.update(from: result, currentVersion: "1.0.1")
        #expect(update == .init(version: "1.1.0", downloadURL: URL(string: "https://example.com/app.dmg")))
    }

    @Test func sameVersionIsNotReported() throws {
        let result = try response(#"{"latest_version": "1.0.1", "update_available": true}"#)
        #expect(UpdateChecker.update(from: result, currentVersion: "1.0.1") == nil)
    }

    @Test func serverFlagFalseWins() throws {
        let result = try response(#"{"latest_version": "9.0", "update_available": false}"#)
        #expect(UpdateChecker.update(from: result, currentVersion: "1.0.1") == nil)
    }

    @Test func nonHTTPSDownloadLinkIsDropped() throws {
        let result = try response(#"{"latest_version": "1.1", "download_url": "http://example.com/app.dmg"}"#)
        let update = UpdateChecker.update(from: result, currentVersion: "1.0.1")
        #expect(update?.version == "1.1")
        #expect(update?.downloadURL == nil)
    }
}
