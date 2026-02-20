//
// EventRowView.swift
//

import SwiftUI
import EventKit

struct EventRowView: View {
    let event: EKEvent

    private var isCurrentEvent: Bool {
        let now = Date()
        return event.startDate <= now && event.endDate > now
    }

    private var isPastEvent: Bool {
        return event.endDate <= Date()
    }

    private var timeString: String {
        if event.isAllDay { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: Locale.current)
        return "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate))"
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
            if let url = URL(string: generateEventURL(event: event)) {
                NSLog("Opening Calendar URL: \(url)")
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func generateEventURL(event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone.current

        var dateComponent = ""
        if event.hasRecurrenceRules {
            if let startDate = event.startDate {
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                formatter.timeZone = TimeZone.current
                if !event.isAllDay {
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                }
                dateComponent = "/\(formatter.string(from: startDate))"
            }
        }
        return "ical://ekevent\(dateComponent)/\(event.calendarItemIdentifier)?method=show&options=more"
    }    
}
