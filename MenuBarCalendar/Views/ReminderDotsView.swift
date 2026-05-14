//
// ReminderDotsView.swift
//

import SwiftUI

struct ReminderDotsView: View {
    let colors: [CGColor]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .stroke(Color(cgColor: colors[index]), lineWidth: 1)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}
