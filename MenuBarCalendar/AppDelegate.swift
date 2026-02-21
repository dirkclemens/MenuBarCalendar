//
//  AppDelegate.swift
//

import SwiftUI
import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate!
    var calendarManager: CalendarManager = CalendarManager()
    private var settingsWindow: NSWindow?
    private var iconUpdateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        // no Dock Icon
        NSApp.setActivationPolicy(.accessory)
        scheduleIconUpdate()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        calendarManager.refreshAuthorization()
        calendarManager.refreshToday()
    }

    // MARK: - Settings window

    @objc func openSettings() {
        if settingsWindow == nil {
            let showSettings = Binding<Bool>(get: { true }, set: { [weak self] _ in self?.settingsWindow?.close() })
            let view = SettingsView(showSettings: showSettings, calendarManager: calendarManager)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = NSLocalizedString("SettingsMenuTitle", comment: "")
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 400, height: 500))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Launch at login

    @objc func toggleLaunchOnLogin() {
        setLaunchOnLogin(enabled: !isLaunchOnLoginEnabled())
    }

    func isLaunchOnLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchOnLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Menu bar icon

    static func makeMenuBarImage(for date: Date = Date()) -> NSImage? {
        let imageSize = NSSize(width: 20, height: 20)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let base = NSImage(named: NSImage.Name("CalendarFrame"))
            ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            ?? NSImage()
        base.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .sourceOver, fraction: 1.0)

        let day = "\(Calendar.current.component(.day, from: date))"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let str = NSAttributedString(string: day, attributes: attrs)
        let size = str.size()
        str.draw(in: NSRect(
            x: (imageSize.width - size.width) / 2,
            y: (imageSize.height - size.height) / 2 - 1,
            width: size.width,
            height: size.height
        ))

        image.isTemplate = true
        return image
    }

    private func scheduleIconUpdate() {
        iconUpdateTimer?.invalidate()
        let calendar = Calendar.current
        if let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) {
            let timer = Timer(fireAt: nextMidnight, interval: 0, target: self,
                              selector: #selector(iconUpdateTimerFired), userInfo: nil, repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            iconUpdateTimer = timer
        }
    }

    @objc private func iconUpdateTimerFired() {
        calendarManager.refreshToday()
        calendarManager.fetchEvents()
        scheduleIconUpdate()
    }

    deinit {
        iconUpdateTimer?.invalidate()
    }
}
