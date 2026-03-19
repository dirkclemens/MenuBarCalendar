//
//  ContentView.swift
//  MenuBarCalendar
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var calendarManager: CalendarManager
    
    private enum Page: Int, CaseIterable {
        case calendar
        case settings
    }
    @State private var page: Page = .calendar
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    goToPreviousPage()
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 12))
                }
                .disabled(page == .calendar)

                Spacer()

                Text(pageTitle)
                    .font(.headline)

                Spacer()

                Button(action: {
                    goToNextPage()
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
                .disabled(page == .settings)
            }

            Divider().frame(height: 1).background(Color.secondary.opacity(0.2))

            ZStack {
                if page == .calendar {
                    CalendarView(calendarManager: calendarManager)
                } else {
                    SettingsView(calendarManager: calendarManager)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)

            Divider().frame(height: 1).background(Color.secondary.opacity(0.2))

            HStack() {
                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                }
    //            .buttonStyle(.plain)
                .buttonStyle(.glass)
                .foregroundColor(.secondary)
                .help(NSLocalizedString("QuitMenuTitle", comment: ""))
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .padding()
        .background(.windowBackground)
        .frame(width: pageWidth, height: pageHeight)
    }

    private var pageWidth: CGFloat  {
        switch page {
        case .calendar:
            return 340
        case .settings:
            return 460
        }
    }

    private var pageHeight: CGFloat  {
        switch page {
        case .calendar:
            return 660
        case .settings:
            return 800
        }
    }
    
    private var pageTitle: String {
        switch page {
        case .calendar:
            return NSLocalizedString("AppTitle", comment: "Menu bar app title")
        case .settings:
            return NSLocalizedString("Settings", comment: "Settings window title")
        }
    }

    private func goToPreviousPage() {
        guard let previous = Page(rawValue: page.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            page = previous
        }
    }

    private func goToNextPage() {
        guard let next = Page(rawValue: page.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            page = next
        }
    }
}

