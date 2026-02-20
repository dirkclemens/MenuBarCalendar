//
// MenuBarCalendarApp.swift
//


import SwiftUI

@main
struct MenuBarCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var calendarManager = CalendarManager()
    @State private var showSettings = false

    var body: some Scene {
        MenuBarExtra {
            CalendarView(calendarManager: calendarManager)
                .onAppear { appDelegate.calendarManager = calendarManager }
        } label: {
            if let image = AppDelegate.makeMenuBarImage() {
                Image(nsImage: image)
            } else {
                Image(systemName: "calendar")
            }
        }
        .menuBarExtraStyle(.window)
        

        Settings {
            SettingsView(showSettings: $showSettings, calendarManager: calendarManager)
        }
    }
}
