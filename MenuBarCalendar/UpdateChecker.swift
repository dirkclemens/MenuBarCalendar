//
//  UpdateChecker.swift
//  MenuBarCalendar
//

import Foundation
import Combine

/// Checks https://api.adcore.de/apps/check.php for a newer version — at launch
/// and then once a day. Sends only app name, app version, macOS version and
/// CPU architecture. The result is shown in the popover footer and in Settings.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    nonisolated struct AvailableUpdate: Equatable {
        let version: String
        let downloadURL: URL?
    }

    @Published private(set) var availableUpdate: AvailableUpdate?

    nonisolated private static let appIdentifier = "MenuBarCalendar"
    nonisolated private static let endpoint = URL(string: "https://api.adcore.de/apps/check.php")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private var timer: Timer?
    private var isChecking = false

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// Checks now and schedules a daily re-check (menu bar apps often run for weeks).
    func start() {
        guard timer == nil else { return }
        checkForUpdate()
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForUpdate() }
        }
        timer.tolerance = 60 * 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func checkForUpdate() {
        guard !isChecking else { return }
        isChecking = true
        Task {
            defer { isChecking = false }
            guard let result = await Self.fetch() else { return }
            availableUpdate = Self.update(from: result, currentVersion: Self.currentVersion)
            #if DEBUG
            print("UpdateChecker: current=\(Self.currentVersion) latest=\(result.latestVersion ?? "?") update=\(availableUpdate?.version ?? "none")")
            #endif
        }
    }

    // MARK: - Networking

    nonisolated private static func fetch() async -> UpdateCheckResponse? {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "app", value: appIdentifier),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "os", value: ProcessInfo.processInfo.operatingSystemVersionString),
            URLQueryItem(name: "arch", value: currentArchitecture),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("\(appIdentifier)/\(version)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(UpdateCheckResponse.self, from: data)
    }

    // MARK: - Evaluation (pure, unit-tested)

    nonisolated static func update(from response: UpdateCheckResponse, currentVersion: String) -> AvailableUpdate? {
        guard response.updateAvailable != false,
              let latest = response.latestVersion,
              isVersion(latest, newerThan: currentVersion) else { return nil }
        // Only accept https links from the server.
        let url = response.downloadURL.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil }
        return AvailableUpdate(version: latest, downloadURL: url)
    }

    /// Numeric comparison, so "1.0.10" is newer than "1.0.9".
    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        candidate.compare(current, options: .numeric) == .orderedDescending
    }

    nonisolated private static var currentArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

nonisolated struct UpdateCheckResponse: Decodable {
    let app: String?
    let currentVersion: String?
    let latestVersion: String?
    let updateAvailable: Bool?
    let downloadURL: String?

    enum CodingKeys: String, CodingKey {
        case app
        case currentVersion = "current_version"
        case latestVersion = "latest_version"
        case updateAvailable = "update_available"
        case downloadURL = "download_url"
    }
}
