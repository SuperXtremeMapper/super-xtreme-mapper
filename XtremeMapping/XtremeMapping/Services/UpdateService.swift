//
//  UpdateService.swift
//  XtremeMapping
//
//  Checks GitHub Releases for updates and downloads DMG files.
//

import Foundation
import SwiftUI

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Update Errors

enum UpdateError: LocalizedError {
    case networkError(Error)
    case invalidResponse(Int)
    case noReleaseFound
    case noDMGAsset
    case downloadFailed(Error)
    case mountFailed(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let code):
            return "Invalid response (HTTP \(code))"
        case .noReleaseFound:
            return "No release found"
        case .noDMGAsset:
            return "Download error, taking you to the SXM website to confirm latest release"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .mountFailed(let message):
            return "Failed to open download: \(message)"
        }
    }
}

// MARK: - Update Service

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    @Published var latestRelease: GitHubRelease?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var isChecking = false

    private let session = URLSession.shared
    private let repoURL = "https://api.github.com/repos/SuperXtremeMapper/super-xtreme-mapper/releases/latest"
    private let websiteURL = "https://superxtrememapper.github.io/super-xtreme-mapper/download.html"

    /// Current app version from Bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Parse version string from GitHub tag (e.g., "v0.5-beta" -> "0.5")
    func parseVersion(from tag: String) -> String {
        var version = tag
        // Remove "v" prefix
        if version.hasPrefix("v") {
            version = String(version.dropFirst())
        }
        // Remove "-beta" or similar suffix
        if let dashIndex = version.firstIndex(of: "-") {
            version = String(version[..<dashIndex])
        }
        return version
    }

    /// Compare two version strings (returns true if remote > current)
    func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteComponents = remote.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(remoteComponents.count, currentComponents.count) {
            let r = i < remoteComponents.count ? remoteComponents[i] : 0
            let c = i < currentComponents.count ? currentComponents[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    /// Check for updates from GitHub
    /// - Parameter force: If true, bypass rate limiting
    /// - Returns: GitHubRelease if update available, nil if up to date
    func checkForUpdate(force: Bool = false) async throws -> GitHubRelease? {
        // Rate limiting for auto-checks
        if !force && !UpdatePreferences.shouldAutoCheck() {
            return nil
        }

        isChecking = true
        defer { isChecking = false }

        guard let url = URL(string: repoURL) else {
            throw UpdateError.noReleaseFound
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("XtremeMapping", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.noReleaseFound
        }

        guard httpResponse.statusCode == 200 else {
            throw UpdateError.invalidResponse(httpResponse.statusCode)
        }

        // Record successful check
        UpdatePreferences.recordCheck()

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let remoteVersion = parseVersion(from: release.tagName)

        // Check if this version should be ignored
        if UpdatePreferences.shouldIgnore(version: remoteVersion) {
            return nil
        }

        // Compare versions
        if isNewerVersion(remoteVersion, than: currentVersion) {
            // Clear any previously ignored version since there's a newer one
            if remoteVersion != UpdatePreferences.ignoredVersion {
                UpdatePreferences.clearIgnored()
            }
            latestRelease = release
            return release
        }

        return nil
    }
}
