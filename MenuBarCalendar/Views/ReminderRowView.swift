//
// ReminderRowView.swift
//

import SwiftUI
import EventKit

struct ReminderRowView: View {
    let reminder: EKReminder
    
    private var timeLabel: String? {
        guard let components = reminder.dueDateComponents,
              let hour = components.hour,
              let minute = components.minute else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if let format = DateFormatter.dateFormat(fromTemplate: "j:mm", options: 0, locale: Locale.current) {
            formatter.dateFormat = format
        } else {
            formatter.dateFormat = "HH:mm"
        }
        let cal = Calendar.current
        let date = cal.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundColor(Color(cgColor: reminder.calendar.cgColor))
            
            if let time = timeLabel {
                Text(time)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
            
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
