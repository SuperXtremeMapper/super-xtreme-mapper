//
//  UpdatePreferences.swift
//  XtremeMapping
//
//  Stores user preferences for update checking.
//

import SwiftUI

struct UpdatePreferences {
    /// Version string the user chose to ignore (e.g., "0.5")
    @AppStorage("update.ignoredVersion") static var ignoredVersion: String = ""

    /// Last update check timestamp (TimeInterval since 1970)
    @AppStorage("update.lastCheckDate") static var lastCheckDate: Double = 0

    /// Check if we should skip showing update prompt for this version
    static func shouldIgnore(version: String) -> Bool {
        return ignoredVersion == version
    }

    /// Check if enough time has passed since last auto-check (24 hours)
    static func shouldAutoCheck() -> Bool {
        let lastCheck = Date(timeIntervalSince1970: lastCheckDate)
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        return hoursSinceLastCheck >= 24
    }

    /// Record that we just checked for updates
    static func recordCheck() {
        lastCheckDate = Date().timeIntervalSince1970
    }

    /// Ignore a specific version
    static func ignore(version: String) {
        ignoredVersion = version
    }

    /// Clear ignored version (called when newer version available)
    static func clearIgnored() {
        ignoredVersion = ""
    }
}
