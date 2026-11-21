//
// EventsListView.swift
//

import SwiftUI
import EventKit

struct EventsListView: View {
    @ObservedObject var calendarManager: CalendarManager
    @AppStorage("eventsListDaysRange") private var eventsListDaysRange = 7
    @AppStorage("showReminders") private var showReminders = true

    private struct DayGroup: Identifiable {
        let id: Date
        let dayLabel: String
        let dateLabel: String
        let events: [EKEvent]
        let reminders: [EKReminder]
    }

    /// Scroll target: the day section and the row of the running or next event.
    private struct ScrollTarget {
        let groupID: Date
        let rowID: String
    }

    /// Unique, stable id for an event row. `eventIdentifier` alone is not unique:
    /// all occurrences of a recurring event share it, and multi-day events appear on several days.
    static func rowID(day: Date, event: EKEvent) -> String {
        "\(day.timeIntervalSinceReferenceDate)|\(event.eventIdentifier ?? event.calendarItemIdentifier)|\(event.startDate.timeIntervalSinceReferenceDate)"
    }

    private func makeGroups() -> [DayGroup] {
        var result: [DayGroup] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: calendarManager.selectedDate)

        for _ in 0..<max(1, eventsListDaysRange) {
            let dayEvents = calendarManager.events(for: currentDate)
            let dayReminders = showReminders ? calendarManager.reminders(for: currentDate) : []
            if !dayEvents.isEmpty || !dayReminders.isEmpty {
                result.append(DayGroup(
                    id: currentDate,
                    dayLabel: dayLabelFor(date: currentDate),
                    dateLabel: Formatters.longDate.string(from: currentDate),
                    events: dayEvents,
                    reminders: dayReminders
                ))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
        }
        return result
    }

    private func dayLabelFor(date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return NSLocalizedString("DayLabelToday", comment: "")
        } else if calendar.isDateInTomorrow(date) {
            return NSLocalizedString("DayLabelTomorrow", comment: "")
        } else {
            return Formatters.weekday.string(from: date)
        }
    }

    private func scrollTarget(in groups: [DayGroup]) -> ScrollTarget? {
        let now = Date()
        let candidates = groups.flatMap { group in group.events.map { (group.id, $0) } }
        guard let (groupID, event) = candidates.first(where: { $0.1.startDate <= now && $0.1.endDate > now })
                ?? candidates.first(where: { $0.1.startDate > now }) else { return nil }
        return ScrollTarget(groupID: groupID, rowID: Self.rowID(day: groupID, event: event))
    }

    var body: some View {
        // Computed once per render (was previously recomputed three times).
        let groups = makeGroups()

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !calendarManager.hasAccess && !calendarManager.hasRemindersAccess {
                        NoAccessView()
                    } else if groups.isEmpty {
                        EmptyEventsView()
                    } else {
                        ForEach(groups) { group in
                            DaySectionView(
                                day: group.id,
                                dayLabel: group.dayLabel,
                                dateLabel: group.dateLabel,
                                events: group.events,
                                reminders: group.reminders
                            )
                            .id(group.id)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxHeight: 400)
            .onAppear { scrollToCurrentEvent(proxy: proxy, target: scrollTarget(in: groups)) }
            .onChange(of: calendarManager.scrollToCurrentEventTrigger) { _, _ in
                scrollToCurrentEvent(proxy: proxy, target: scrollTarget(in: makeGroups()))
            }
        }
    }

    private func scrollToCurrentEvent(proxy: ScrollViewProxy, target: ScrollTarget?) {
        guard let target else { return }
        // Step 1: scroll the day section header into view instantly
        proxy.scrollTo(target.groupID, anchor: .top)
        // Step 2: after the header is rendered, animate to the target event
        // using a top-biased anchor so the day header remains visible above it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(target.rowID, anchor: UnitPoint(x: 0.5, y: 0.15))
            }
        }
    }
}
