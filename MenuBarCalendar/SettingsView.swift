//
//  SettingsView.swift
//  parts taken from https://github.com/harryfliu
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

struct CalendarsListView: View {
    @ObservedObject var calendarManager: CalendarManager

    private var groupedCalendars: [(String, [EKCalendar])] {
        var groups: [String: [EKCalendar]] = [:]

        for calendar in calendarManager.calendars {
            let sourceName = calendar.source.title
            if groups[sourceName] == nil {
                groups[sourceName] = []
            }
            groups[sourceName]?.append(calendar)
        }

        // Sort groups by name, but put iCloud first if present
        return groups.sorted { first, second in
            if first.key.lowercased().contains("icloud") { return true }
            if second.key.lowercased().contains("icloud") { return false }
            return first.key < second.key
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(groupedCalendars, id: \.0) { sourceName, calendars in
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceName)
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(calendars, id: \.calendarIdentifier) { calendar in
                            CalendarToggleRow(
                                calendar: calendar,
                                isEnabled: calendarManager.isCalendarEnabled(calendar),
                                onToggle: { calendarManager.toggleCalendar(calendar) }
                            )
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct CalendarToggleRow: View {
    let calendar: EKCalendar
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Toggle(isOn: Binding<Bool>(
                    get: { isEnabled },
                    set: { _ in onToggle() }
                )) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 12, height: 12)

                        Text(calendar.title)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                }
                .focusable(false)
                .accessibility(label: Text(String(format: NSLocalizedString("CalendarAccessibilityLabel", comment: ""), calendar.title)))
                .buttonSizing(.flexible) // macOS 26 API
                
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRowView: View {
    let icon: String
    let title: String
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
