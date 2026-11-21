//
// UpdateBadgeView.swift
//

import SwiftUI

/// Small footer hint shown when a newer version is available.
struct UpdateBadgeView: View {
    let update: UpdateChecker.AvailableUpdate

    private var title: String {
        String(format: NSLocalizedString("UpdateAvailableFormat", comment: ""), update.version)
    }

    var body: some View {
        Button {
            if let url = update.downloadURL {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Label(title, systemImage: "arrow.down.circle")
                .font(.system(size: 11))
        }
        .buttonStyle(.glass)
        .disabled(update.downloadURL == nil)
        .help(title)
    }
}
