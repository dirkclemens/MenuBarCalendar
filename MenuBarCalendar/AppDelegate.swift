//
//  AppDelegate.swift
//

import SwiftUI
import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var instance: AppDelegate?
    var calendarManager: CalendarManager = .shared
    private var iconUpdateTimer: Timer?
    private var eventRefreshTimer: Timer?
    private var nextEventTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.instance = self
        // no Dock Icon
        NSApp.setActivationPolicy(.accessory)
        scheduleIconUpdate()
        scheduleEventRefresh()
        scheduleNextEventUpdates()
        UpdateChecker.shared.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        // Day / time zone / clock changes (e.g. travelling, manual clock change)
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(dateEnvironmentDidChange),
                                                   name: name, object: nil)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Re-checks permissions; on success this also refreshes today's date and reloads events.
        calendarManager.refreshAuthorization()
    }

    // MARK: - Launch at login

    func isLaunchOnLoginEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchOnLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    // MARK: - Menu bar icon

    private static var cachedMenuBarImage: (day: Int, image: NSImage)?

    /// Returns the calendar icon with the day number. The image is cached per day,
    /// because the menu bar label is re-evaluated on every published model change.
    static func makeMenuBarImage(for date: Date = Date()) -> NSImage? {
        let dayNumber = Calendar.current.component(.day, from: date)
        if let cached = cachedMenuBarImage, cached.day == dayNumber {
            return cached.image
        }
        let image = renderMenuBarImage(day: dayNumber)
        cachedMenuBarImage = (dayNumber, image)
        return image
    }

    private static func renderMenuBarImage(day dayNumber: Int) -> NSImage {
        let imageSize = NSSize(width: 20, height: 20)
        let image = NSImage(size: imageSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let base = NSImage(named: NSImage.Name("CalendarFrame"))
            ?? NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")
            ?? NSImage()
        base.draw(in: NSRect(origin: .zero, size: imageSize), from: .zero, operation: .sourceOver, fraction: 1.0)

        let day = "\(dayNumber)"
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
        calendarManager.refreshVisibleContent()
        scheduleIconUpdate()
    }

    // MARK: - 15-minute event refresh
    private func scheduleEventRefresh() {
        eventRefreshTimer?.invalidate()
        let timer = Timer(timeInterval: 15 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.calendarManager.refreshVisibleContent() }
        }
        RunLoop.main.add(timer, forMode: .common)
        eventRefreshTimer = timer
    }

    // MARK: - Menu bar "next event" label

    /// Re-evaluates the menu bar label every minute so finished events disappear
    /// promptly. Cheap: it only filters already loaded events and publishes on change.
    private func scheduleNextEventUpdates() {
        nextEventTimer?.invalidate()
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.calendarManager.refreshNextEvent() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        nextEventTimer = timer
    }

    @objc private func systemDidWake(_ notification: Notification) {
        handleDateEnvironmentChange()
    }

    /// These notifications may be posted on any thread, so hop to the main actor.
    @objc nonisolated private func dateEnvironmentDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.handleDateEnvironmentChange()
        }
    }

    private func handleDateEnvironmentChange() {
        calendarManager.refreshToday()
        calendarManager.refreshVisibleContent()
        scheduleIconUpdate()
    }

    deinit {
        iconUpdateTimer?.invalidate()
        eventRefreshTimer?.invalidate()
        nextEventTimer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
}
