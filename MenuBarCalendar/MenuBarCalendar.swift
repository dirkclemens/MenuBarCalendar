//
//  MenuBarCalendarApp.swift
//


import SwiftUI
import EventKit

@main
struct MenuBarCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var calendarManager = CalendarManager()
    @State private var showSettings = false
    @AppStorage("showNextEventInMenuBar") private var showNextEventInMenuBar = true

    var body: some Scene {
        MenuBarExtra {
            CalendarView(calendarManager: calendarManager)
                .onAppear { appDelegate.calendarManager = calendarManager }
        } label: {
            HStack(spacing: 4) {
                if let image = AppDelegate.makeMenuBarImage(for: calendarManager.today) {
                    Image(nsImage: image)
                } else {
                    Image(systemName: "calendar")
                }
                
                if showNextEventInMenuBar, let event = calendarManager.nextEvent {
                    MenuBarEventLabel(event: event)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(showSettings: $showSettings, calendarManager: calendarManager)
        }
    }
}

/// Compact event label shown in the menu bar next to the calendar icon.
struct MenuBarEventLabel: View {
    let event: EKEvent

    private var label: String {
        let title = event.title ?? NSLocalizedString("UntitledEvent", comment: "")
        if event.isAllDay { return title }
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: Locale.current)
        return " \(formatter.string(from: event.startDate)) \(title)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 10, weight: .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 100)
        }
    }
}
