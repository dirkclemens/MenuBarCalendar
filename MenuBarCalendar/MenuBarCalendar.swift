//
//  MenuBarCalendar.swift
//

import SwiftUI

@main
struct MenuBarCalendar: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var calendarManager = CalendarManager()
    @State private var showSettings: Bool = false
    
    var body: some Scene {
        Settings {
            SettingsView(showSettings: $showSettings, calendarManager: calendarManager)
        }
    }
}
