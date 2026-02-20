//
// NoAccessView.swift
//

import SwiftUI
import EventKit

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
