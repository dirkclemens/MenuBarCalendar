//
// WeekNumberView.swift
//

import SwiftUI

struct WeekNumberView: View {
    let number: Int?

    var body: some View {
        Text(number.map { "\($0)" } ?? "-")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
    }
}
