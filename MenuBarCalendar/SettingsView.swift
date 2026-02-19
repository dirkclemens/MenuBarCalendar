//
//  SettingsView.swift
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("keepWindowOpen") private var keepWindowOpen = false
    @Binding var showSettings: Bool
    @ObservedObject var calendarManager: CalendarManager
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Keep Window Open", isOn: $keepWindowOpen)
            }
            
            SettingsSectionView(title: "Privacy") {
                SettingsRowView(
                    icon: "lock.shield",
                    title: "Calendar Privacy Settings",
                    action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
    }
}
