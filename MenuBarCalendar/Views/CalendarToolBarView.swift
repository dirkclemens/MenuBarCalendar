//
// CalendarToolBarView.swift
//

import SwiftUI

struct CalendarToolBarView: View {

    var body: some View {
        HStack {
            Button(action: { AppDelegate.instance.openSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
            }
//            .buttonStyle(.plain)
            .buttonStyle(.glass)
            .foregroundColor(.secondary)
            .help(NSLocalizedString("SettingsMenuTitle", comment: ""))

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 12))
            }
//            .buttonStyle(.plain)
            .buttonStyle(.glass)
            .foregroundColor(.secondary)
            .help(NSLocalizedString("QuitMenuTitle", comment: ""))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
