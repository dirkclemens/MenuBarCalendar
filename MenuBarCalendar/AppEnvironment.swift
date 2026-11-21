//
//  AppEnvironment.swift
//  MenuBarCalendar
//

import Foundation

enum AppEnvironment {
    /// True while the app runs as host for the unit tests. Used to skip
    /// permission prompts, timers and network requests during tests.
    nonisolated static let isRunningTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }()
}
