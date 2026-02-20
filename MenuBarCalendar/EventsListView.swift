//
// originally created by https://github.com/harryfliu and Claude Code
//    https://github.com/harryfliu/itsybitsycal/blob/main/Itsybitsycal/EventsListView.swift
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
        let endDate = calendar.date(byAdding: .day, value: 21, to: currentDate)!

        while currentDate < endDate {
            let dayEvents = calendarManager.events(for: currentDate)
            if !dayEvents.isEmpty {
                let dayLabel = dayLabelFor(date: currentDate)
                let dateLabel = dateLabelFor(date: currentDate)
                result.append(DayGroup(id: currentDate, dayLabel: dayLabel, dateLabel: dateLabel, events: dayEvents))
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

    /// Find the current or next upcoming event to scroll to
    private var targetEventId: String? {
        let now = Date()
        var allEvents: [EKEvent] = []

        for dayGroup in groupedEvents {
            allEvents.append(contentsOf: dayGroup.events)
        }

        // First, look for a currently happening event
        if let currentEvent = allEvents.first(where: { $0.startDate <= now && $0.endDate > now }) {
            return currentEvent.eventIdentifier
        }

        // Otherwise, find the next upcoming event
        if let nextEvent = allEvents.first(where: { $0.startDate > now }) {
            return nextEvent.eventIdentifier
        }

        return nil
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
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(minHeight: 300)
            .frame(maxHeight: 400)
            .onAppear {
                scrollToCurrentEvent(proxy: proxy)
            }
            .onChange(of: calendarManager.scrollToCurrentEventTrigger) { _, _ in
                scrollToCurrentEvent(proxy: proxy)
            }
        }
    }

    private func scrollToCurrentEvent(proxy: ScrollViewProxy) {
        if let eventId = targetEventId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(eventId, anchor: .top)
                }
            }
        }
    }
}

struct NoAccessView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text(NSLocalizedString("CalendarAccessRequired", comment: ""))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button(NSLocalizedString("OpenSystemSettings", comment: "")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

struct EmptyEventsView: View {
    var body: some View {
        Text(NSLocalizedString("NoUpcomingEvents", comment: ""))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }
}

struct DaySectionView: View {
    let dayLabel: String
    let dateLabel: String
    let events: [EKEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day header
            HStack {
                Text(dayLabel)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(dateLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Events
            ForEach(events, id: \.eventIdentifier) { event in
                EventRowView(event: event)
                    .id(event.eventIdentifier)
            }
        }
    }
}

struct EventRowView: View {
    let event: EKEvent

    private var isCurrentEvent: Bool {
        let now = Date()
        return event.startDate <= now && event.endDate > now
    }

    private var isPastEvent: Bool {
        let now = Date()
        return event.endDate <= now
    }

    private var timeString: String {
        if event.isAllDay {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) – \(end)"
    }

    private var hasVideoCall: Bool {
        if let notes = event.notes, notes.contains("zoom.us") || notes.contains("meet.google") || notes.contains("teams.microsoft") {
            return true
        }
        if let url = event.url, let urlString = url.absoluteString.lowercased() as String?,
           urlString.contains("zoom") || urlString.contains("meet.google") || urlString.contains("teams") {
            return true
        }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
                .opacity(isPastEvent ? 0.5 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? NSLocalizedString("UntitledEvent", comment: ""))
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(isPastEvent ? .secondary : .primary)

                if !timeString.isEmpty {
                    HStack(spacing: 4) {
                        Text(timeString)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .opacity(isPastEvent ? 0.7 : 1.0)

                        if hasVideoCall {
                            Image(systemName: "video")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .opacity(isPastEvent ? 0.7 : 1.0)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrentEvent ? Color.accentColor.opacity(0.15) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            AppDelegate.instance.openSettings()
        }
    }
}
