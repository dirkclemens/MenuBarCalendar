//
// CalendarSelectionView.swift
//

import SwiftUI
import EventKit

struct CalendarSelectionView: View {
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

                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
