//
// SettingsRowView.swift
//

import SwiftUI

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
