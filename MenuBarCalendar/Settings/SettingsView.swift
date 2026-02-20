//
//  SettingsView.swift
//


import SwiftUI
import EventKit

struct SettingsView: View {
    @Binding var showSettings: Bool
    @ObservedObject var calendarManager: CalendarManager

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
            
            Section(NSLocalizedString("SettingsGeneral", comment: "")) {
                Toggle(NSLocalizedString("LaunchAtLoginMenuTitle", comment: ""), isOn: Binding(
                    get: { AppDelegate.instance.isLaunchOnLoginEnabled() },
                    set: { _ in AppDelegate.instance.toggleLaunchOnLogin() }
                ))
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
        .padding(2)
    }
}
