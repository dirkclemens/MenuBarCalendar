//
// EventsListView.swift
//

import SwiftUI
import EventKit

struct EventsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private struct DayGroup: Identifiable {
        let id: Date
        let dayLabel: String
        let dateLabel: String
        let events: [EKEvent]
    }

    private var groupedEvents: [DayGroup] {
        var result: [DayGroup] = []
        let calendar = Calendar.current
        var currentDate = calendarManager.selectedDate
        let endDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!

        while currentDate < endDate {
            let dayEvents = calendarManager.events(for: currentDate)
            if !dayEvents.isEmpty {
                result.append(DayGroup(
                    id: currentDate,
                    dayLabel: dayLabelFor(date: currentDate),
                    dateLabel: dateLabelFor(date: currentDate),
                    events: dayEvents
                ))
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
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
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }

    private func dateLabelFor(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private var targetGroupId: Date? {
        let now = Date()
        let allEvents = groupedEvents.flatMap { $0.events }
        let targetEvent = allEvents.first(where: { $0.startDate <= now && $0.endDate > now })
            ?? allEvents.first(where: { $0.startDate > now })
        guard let target = targetEvent else { return nil }
        return groupedEvents.first(where: { group in
            group.events.contains { $0.eventIdentifier == target.eventIdentifier }
        })?.id
    }

    private var targetEventId: String? {
        let now = Date()
        let allEvents = groupedEvents.flatMap { $0.events }
        return allEvents.first(where: { $0.startDate <= now && $0.endDate > now })?.eventIdentifier
            ?? allEvents.first(where: { $0.startDate > now })?.eventIdentifier
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !calendarManager.hasAccess {
                        NoAccessView()
                    } else if groupedEvents.isEmpty {
                        EmptyEventsView()
                    } else {
                        ForEach(groupedEvents) { group in
                            DaySectionView(
                                dayLabel: group.dayLabel,
                                dateLabel: group.dateLabel,
                                events: group.events
                            )
                            .id(group.id)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(maxHeight: 400)
            .onAppear { scrollToCurrentEvent(proxy: proxy) }
            .onChange(of: calendarManager.scrollToCurrentEventTrigger) { _, _ in
                scrollToCurrentEvent(proxy: proxy)
            }
        }
    }

    private func scrollToCurrentEvent(proxy: ScrollViewProxy) {
        // Step 1: scroll the day section header into view instantly
        if let groupId = targetGroupId {
            proxy.scrollTo(groupId, anchor: .top)
        }
        // Step 2: after the header is rendered, animate to the target event
        // using a top-biased anchor so the day header remains visible above it
        guard let eventId = targetEventId else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(eventId, anchor: UnitPoint(x: 0.5, y: 0.15))
            }
        }
    }
}
