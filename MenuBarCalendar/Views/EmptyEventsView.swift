//
// EmptyEventsView.swift
//

import SwiftUI

struct EmptyEventsView: View {
    var body: some View {
        Text(NSLocalizedString("NoUpcomingEvents", comment: ""))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }
}
