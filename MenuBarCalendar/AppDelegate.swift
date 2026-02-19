//
//  AppDelegate.swift
//

import SwiftUI
import AppKit
import ServiceManagement
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate! // do not remove!
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var calendarManager = CalendarManager()
    private var settingsWindow: NSWindow?
    private var iconUpdateTimer: Timer?
    static let closePopoverNotification = Notification.Name("MenuBarClendarClosePopover")
    static let reopenPopoverNotification = Notification.Name("MenuBarClendarReopenPopover")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = makeStatusItemImage()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        scheduleIconUpdate()
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 600, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: CalendarView(calendarManager: calendarManager))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopover),
            name: AppDelegate.closePopoverNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReopenPopover),
            name: AppDelegate.reopenPopoverNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        calendarManager.refreshAuthorization()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
            return
        }
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                calendarManager.refreshAuthorization()
                // Read latest setting value.
                let keepOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")
                popover?.behavior = keepOpen ? .applicationDefined : .transient
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover?.contentViewController?.view.window?.makeKey()
                DispatchQueue.main.async { [weak self] in
                    self?.configurePopoverWindow()
                }
            }
        }
    }

    private func configurePopoverWindow() {
        guard let window = popover?.contentViewController?.view.window else { return }
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 420, height: 280)
        window.setFrameAutosaveName("MenuBarClendarPopoverFrame")
        window.setFrameUsingName("xMenuBarAppPopoverFrame")
    }

    private func showMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchOnLogin), keyEquivalent: "l")
        launchItem.state = isLaunchOnLoginEnabled() ? .on : .off
        launchItem.target = self
        menu.addItem(launchItem)
        
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem?.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
        }
    }

    @objc private func handleClosePopover() {
        popover?.performClose(nil)
    }

    @objc private func handleReopenPopover() {
        NSApp.activate(ignoringOtherApps: true)
        guard let button = statusItem?.button else { return }
        let keepOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")
        popover?.behavior = keepOpen ? .applicationDefined : .transient
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover?.contentViewController?.view.window?.makeKey()
        DispatchQueue.main.async { [weak self] in
            self?.configurePopoverWindow()
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let showSettings = Binding<Bool>(get: { true }, set: { [weak self] _ in self?.settingsWindow?.close() })
            let view = SettingsView(showSettings: showSettings, calendarManager: calendarManager)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 400, height: 500))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func toggleLaunchOnLogin() {
        let enabled = isLaunchOnLoginEnabled()
        setLaunchOnLogin(enabled: !enabled)
    }

    private func isLaunchOnLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                return true
            default:
                return false
            }
        } else {
            // On older systems, avoid deprecated APIs and report disabled.
            return false
        }
    }

    private func setLaunchOnLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // You may want to surface this error to the user in UI or logging
                NSLog("Failed to update launch at login: \(error.localizedDescription)")
            }
        } else {
            // On older macOS versions, we do not attempt to manage login items to avoid deprecated APIs.
            NSLog("Launch at login management is unavailable on this macOS version.")
        }
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        button.image = makeStatusItemImage()
    }

    private func scheduleIconUpdate() {
        iconUpdateTimer?.invalidate()

        updateStatusBarIcon()

        let calendar = Calendar.current
        if let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) {
            let timer = Timer(fireAt: nextMidnight, interval: 0, target: self, selector: #selector(iconUpdateTimerFired(_:)), userInfo: nil, repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            iconUpdateTimer = timer
        } else {
            iconUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.updateStatusBarIcon()
            }
        }
    }

    @objc private func iconUpdateTimerFired(_ timer: Timer) {
        updateStatusBarIcon()
        scheduleIconUpdate()
    }

    private func makeStatusItemImage(for date: Date = Date()) -> NSImage {
        let imageSize = NSSize(width: 20, height: 20)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let assetImage = NSImage(named: NSImage.Name("CalendarFrame")) ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
        let baseImage = assetImage ?? NSImage()
        baseImage.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .sourceOver, fraction: 1.0)

        let day = "\(Calendar.current.component(.day, from: date))"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        let attrString = NSAttributedString(string: day, attributes: attributes)
        let textSize = attrString.size()
        let textRect = NSRect(
            x: (imageSize.width - textSize.width) / 2,
            y: (imageSize.height - textSize.height) / 2 - 1,
            width: textSize.width,
            height: textSize.height
        )
        attrString.draw(in: textRect)

        image.isTemplate = true
        return image
    }

    deinit {
        iconUpdateTimer?.invalidate()
    }
}
