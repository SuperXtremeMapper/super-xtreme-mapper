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

    /// Find the DMG asset in release assets
    func findDMGAsset(in release: GitHubRelease) -> GitHubAsset? {
        return release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }

    /// Download the DMG file with progress tracking
    func downloadUpdate(asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.noDMGAsset
        }

        isDownloading = true
        downloadProgress = 0

        defer { isDownloading = false }

        // Create download destination in Downloads folder
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsURL.appendingPathComponent(asset.name)

        // Remove existing file if present
        try? FileManager.default.removeItem(at: destinationURL)

        // Download with progress
        let (asyncBytes, response) = try await session.bytes(from: url)

        let expectedLength = (response as? HTTPURLResponse)?.expectedContentLength ?? Int64(asset.size)

        var data = Data()
        data.reserveCapacity(Int(expectedLength))

        for try await byte in asyncBytes {
            data.append(byte)
            let progress = Double(data.count) / Double(expectedLength)
            await MainActor.run {
                self.downloadProgress = min(progress, 1.0)
            }
        }

        // Write to file
        try data.write(to: destinationURL)

        return destinationURL
    }

    /// Mount the downloaded DMG
    func mountDMG(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-autoopen"]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw UpdateError.mountFailed(errorMessage)
        }
    }

    /// Open the website download page (fallback when DMG not found)
    func openWebsiteDownload() {
        if let url = URL(string: websiteURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
