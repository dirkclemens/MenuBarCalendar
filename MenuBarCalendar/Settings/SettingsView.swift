//
//  SettingsView.swift
//


import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @AppStorage("showNextEventInMenuBar") private var showNextEventInMenuBar = true
    @AppStorage("eventsListDaysRange") private var eventsListDaysRange = 7
    @AppStorage("showReminders") private var showReminders = true
    @AppStorage("showAllDayEventsInMenuBar") private var showAllDayEventsInMenuBar = false
    @State private var launchAtLogin = AppDelegate.instance?.isLaunchOnLoginEnabled() ?? false

    var body: some View {
        Form {
            Section(NSLocalizedString("SettingsCalendars", comment: "")) {
                VStack {
                    CalendarsListView(calendarManager: calendarManager)
                    Text(NSLocalizedString("SettingsCalendarsHint", comment: ""))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            Section(NSLocalizedString("SettingsReminders", comment: "")) {
                Toggle(NSLocalizedString("SettingsShowReminders", comment: ""), isOn: $showReminders)
                
                if showReminders && calendarManager.hasRemindersAccess {
                    ReminderListsView(calendarManager: calendarManager)
                }
                
                if !calendarManager.hasRemindersAccess {
                    SettingsRowView(
                        icon: "lock.shield",
                        title: NSLocalizedString("SettingsRemindersPrivacy", comment: ""),
                        action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    )
                }
            }
            
            Section(NSLocalizedString("SettingsGeneral", comment: "")) {
                Toggle(NSLocalizedString("LaunchAtLoginMenuTitle", comment: ""), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard let appDelegate = AppDelegate.instance,
                              appDelegate.isLaunchOnLoginEnabled() != enabled else { return }
                        appDelegate.setLaunchOnLogin(enabled: enabled)
                        // Reflect the real state if registration failed or needs approval.
                        launchAtLogin = appDelegate.isLaunchOnLoginEnabled()
                    }
                
                Stepper(value: $eventsListDaysRange, in: 1...30, step: 1) {
                    Text(String(
                        format: NSLocalizedString("SettingsEventsRangeFormat", comment: ""),
                        eventsListDaysRange
                    ))
                }
                .onChange(of: eventsListDaysRange) { _, _ in
                    calendarManager.refreshVisibleContent(force: false)
                }
                
                Toggle(NSLocalizedString("SettingsShowNextEvent", comment: ""), isOn: $showNextEventInMenuBar)
                if showNextEventInMenuBar {
                    Toggle(NSLocalizedString("SettingsShowAllDayEvents", comment: ""), isOn: $showAllDayEventsInMenuBar)
                        .onChange(of: showAllDayEventsInMenuBar) { _, _ in
                            calendarManager.refreshNextEvent()
                        }
                }
            }
            
            Section(NSLocalizedString("SettingsEvents", comment: "")) {
                SettingsRowView(
                    icon: "lock.shield",
                    title: NSLocalizedString("SettingsCalendarPrivacy", comment: ""),
                    action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
