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
                Toggle(NSLocalizedString("LaunchAtLoginMenuTitle", comment: ""), isOn: Binding(
                    get: { AppDelegate.instance.isLaunchOnLoginEnabled() },
                    set: { _ in AppDelegate.instance.toggleLaunchOnLogin() }
                ))
                
                Stepper(value: $eventsListDaysRange, in: 1...30, step: 1) {
                    Text(String(
                        format: NSLocalizedString("SettingsEventsRangeFormat", comment: ""),
                        eventsListDaysRange
                    ))
                }
                .onChange(of: eventsListDaysRange) { _, _ in
                    calendarManager.fetchEvents()
                }
                
                Toggle(NSLocalizedString("SettingsShowNextEvent", comment: ""), isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "showNextEventInMenuBar") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "showNextEventInMenuBar") }
                ))
                if showNextEventInMenuBar {
                    Toggle(NSLocalizedString("SettingsShowAllDayEvents", comment: ""), isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "showAllDayEventsInMenuBar") },
                        set: {
                            UserDefaults.standard.set($0, forKey: "showAllDayEventsInMenuBar")
                            calendarManager.refreshNextEvent()
                        }
                    ))
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
