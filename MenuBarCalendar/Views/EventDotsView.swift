//
// EventDotsView.swift
//

import SwiftUI

struct EventDotsView: View {
    let colors: [CGColor]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<colors.count, id: \.self) { index in
                Circle()
                    .fill(Color(cgColor: colors[index]))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(height: 4)
    }
}
