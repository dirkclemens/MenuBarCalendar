//
// ReminderRowView.swift
//

import SwiftUI
import EventKit

struct ReminderRowView: View {
    let reminder: EKReminder
    /// Marks the reminder as completed; returns false if saving failed.
    var onComplete: (EKReminder) -> Bool = { _ in false }

    @State private var isCompleting = false

    /// Due time, or nil for reminders due on a day without a time (previously shown as "0:00").
    private var timeLabel: String? {
        guard reminder.hasDueTime, let date = reminder.dueDate else { return nil }
        return Formatters.time.string(from: date)
    }

    var body: some View {
        let reminderColor = reminder.calendar.map { Color(cgColor: $0.cgColor) } ?? .secondary

        HStack(spacing: 8) {
            Button(action: complete) {
                Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
                    .foregroundColor(reminderColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            .help(NSLocalizedString("MarkReminderCompleted", comment: ""))
            .accessibilityLabel(NSLocalizedString("MarkReminderCompleted", comment: ""))

            Text(timeLabel ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(reminder.title ?? NSLocalizedString("UntitledReminder", comment: ""))
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(isCompleting)
                .foregroundColor(isCompleting ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            openInReminders()
        }
    }

    private func complete() {
        withAnimation(.easeInOut(duration: 0.2)) { isCompleting = true }
        // Short delay so the checkmark is visible before the row disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !onComplete(reminder) {
                withAnimation { isCompleting = false }
            }
        }
    }

    /// Opens this reminder in the Reminders app (falls back to just opening the app).
    private func openInReminders() {
        let specific = URL(string: "x-apple-reminderkit://REMCDReminder/\(reminder.calendarItemIdentifier)")
        if let url = specific ?? URL(string: "x-apple-reminderkit://") {
            NSWorkspace.shared.open(url)
        }
    }
}
