//
// ReminderRowView.swift
//

import SwiftUI
import EventKit

struct ReminderRowView: View {
    let reminder: EKReminder
    
    /// Due time, or nil for reminders due on a day without a time (previously shown as "0:00").
    private var timeLabel: String? {
        guard reminder.hasDueTime, let date = reminder.dueDate else { return nil }
        return Formatters.time.string(from: date)
    }
    
    var body: some View {
        let reminderColor = reminder.calendar.map { Color(cgColor: $0.cgColor) } ?? .secondary

        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundColor(reminderColor)
            
            Text(timeLabel ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(reminder.title ?? NSLocalizedString("UntitledReminder", comment: ""))
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            openInReminders()
        }
    }
    
    private func openInReminders() {
        // Open the Reminders app
        if let url = URL(string: "x-apple-reminderkit://") {
            NSWorkspace.shared.open(url)
        }
    }
}
