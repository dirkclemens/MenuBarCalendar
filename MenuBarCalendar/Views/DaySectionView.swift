//
// DaySectionView.swift
//

import SwiftUI
import EventKit

struct DaySectionView: View {
    let dayLabel: String
    let dateLabel: String
    let events: [EKEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dayLabel)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(dateLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ForEach(events, id: \.eventIdentifier) { event in
                EventRowView(event: event)
                    .id(event.eventIdentifier)
            }
        }
    }
}
