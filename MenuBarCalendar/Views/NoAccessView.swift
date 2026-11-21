//
// NoAccessView.swift
//

import SwiftUI

/// Hint shown when calendar access is missing. The compact variant is used
/// when reminders are still listed below it.
struct NoAccessView: View {
    var compact = false

    var body: some View {
        if compact {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("CalendarAccessRequired", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                settingsButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("CalendarAccessRequired", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                settingsButton
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    private var settingsButton: some View {
        Button(NSLocalizedString("OpenSystemSettings", comment: "")) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                NSWorkspace.shared.open(url)
            }
        }
        .font(.system(size: 11))
        .buttonStyle(.link)
    }
}
