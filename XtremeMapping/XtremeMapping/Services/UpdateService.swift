//
//  UpdateService.swift
//  XtremeMapping
//
//  Checks GitHub Releases for updates and downloads DMG files.
//

import Combine
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
    case sizeMismatch(expected: Int64, received: Int64)
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
        case .sizeMismatch(let expected, let received):
            return "Download incomplete: expected \(expected) bytes, received \(received)"
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
    /// True when neither the HTTP content length nor the asset size is known —
    /// the UI shows an indeterminate bar instead of a fabricated percentage.
    @Published var isDownloadProgressIndeterminate = false
    @Published var isChecking = false

    private let session = URLSession.shared
    private let repoURL = "https://api.github.com/repos/SuperXtremeMapper/super-xtreme-mapper/releases/latest"
    private let websiteURL = "https://superxtrememapper.github.io/super-xtreme-mapper/download.html"

    /// Current app version from Bundle
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// Parse version string from GitHub tag for display/ignore purposes
    /// (e.g., "v0.5-beta" -> "0.5")
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

    /// Parse a tag/version string into numeric components plus the
    /// pre-release identifier, so "0.5-beta", "0.5-beta2", and "0.5" all
    /// stay distinguishable.
    nonisolated static func parseVersionInfo(_ raw: String) -> (numerics: [Int], prerelease: String?) {
        var version = raw
        if version.hasPrefix("v") {
            version = String(version.dropFirst())
        }
        var prerelease: String? = nil
        if let dashIndex = version.firstIndex(of: "-") {
            prerelease = String(version[version.index(after: dashIndex)...])
            version = String(version[..<dashIndex])
        }
        let numerics = version.split(separator: ".").compactMap { Int($0) }
        return (numerics, prerelease)
    }

    /// Compare two version strings (returns true if remote > current).
    /// Numeric comparison first ("0.9" < "0.10"); when the numerics are
    /// equal, a release beats its own pre-release ("0.5" > "0.5-beta"),
    /// and pre-releases compare by their identifier's trailing number
    /// ("beta2" > "beta") so a respun beta is still offered to beta users.
    nonisolated static func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteInfo = parseVersionInfo(remote)
        let currentInfo = parseVersionInfo(current)

        for i in 0..<max(remoteInfo.numerics.count, currentInfo.numerics.count) {
            let r = i < remoteInfo.numerics.count ? remoteInfo.numerics[i] : 0
            let c = i < currentInfo.numerics.count ? currentInfo.numerics[i] : 0
            if r > c { return true }
            if r < c { return false }
        }

        switch (remoteInfo.prerelease, currentInfo.prerelease) {
        case (nil, .some):
            return true   // final beats its own pre-release
        case (.some, nil), (nil, nil):
            return false
        case let (.some(remotePre), .some(currentPre)):
            return prereleaseRank(remotePre) > prereleaseRank(currentPre)
        }
    }

    /// Orders pre-release identifiers by their trailing number:
    /// "beta" → 0, "beta2" → 2, "beta10" → 10. Different alphabetic stems
    /// are not ordered (rank ties → not newer), which matches this repo's
    /// single-stem tagging.
    nonisolated static func prereleaseRank(_ identifier: String) -> Int {
        let digits = String(identifier.reversed().prefix(while: \.isNumber).reversed())
        return digits.isEmpty ? 0 : (Int(digits) ?? 0)
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

        // Ignore is keyed on the RAW tag so dismissing "v0.5-beta" can't
        // swallow the eventual "v0.5" final release.
        if UpdatePreferences.shouldIgnore(version: release.tagName) {
            return nil
        }

        // Compare versions on the RAW strings — both sides keep their
        // pre-release suffix so a beta user is offered the final release.
        if Self.isNewerVersion(release.tagName, than: currentVersion) {
            // Clear any previously ignored version since there's a newer one
            if release.tagName != UpdatePreferences.ignoredVersion {
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

    /// Download the DMG file with progress tracking.
    /// Streaming and file I/O run off the main actor; progress is published
    /// back to the main actor batched per 64KB chunk.
    func downloadUpdate(asset: GitHubAsset) async throws -> URL {
        guard let url = URL(string: asset.browserDownloadUrl) else {
            throw UpdateError.noDMGAsset
        }

        isDownloading = true
        downloadProgress = 0
        isDownloadProgressIndeterminate = false

        defer { isDownloading = false }

        // Create download destination in Downloads folder
        guard let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw UpdateError.downloadFailed(NSError(domain: "FileSystem", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Downloads folder"]))
        }
        let destinationURL = downloadsURL.appendingPathComponent(asset.name)

        let session = self.session
        let assetSize = Int64(asset.size)
        // nil fraction = indeterminate (no known total to divide by)
        let onProgress: @Sendable (Double?) -> Void = { [weak self] fraction in
            guard let self else { return }
            Task { @MainActor in
                if let fraction {
                    self.isDownloadProgressIndeterminate = false
                    self.downloadProgress = fraction
                } else {
                    self.isDownloadProgressIndeterminate = true
                }
            }
        }

        do {
            try await Task.detached(priority: .userInitiated) {
                try await UpdateService.performDownload(
                    session: session,
                    from: url,
                    to: destinationURL,
                    assetSize: assetSize,
                    onProgress: onProgress
                )
            }.value
        } catch {
            // Never leave a partial DMG behind
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }

        isDownloadProgressIndeterminate = false
        downloadProgress = 1.0
        return destinationURL
    }

    /// Off-main download worker: streams bytes to disk, reports batched
    /// progress, and verifies the byte count against the published asset size.
    nonisolated private static func performDownload(
        session: URLSession,
        from url: URL,
        to destinationURL: URL,
        assetSize: Int64,
        onProgress: @escaping @Sendable (Double?) -> Void
    ) async throws {
        // Remove existing file if present
        try? FileManager.default.removeItem(at: destinationURL)

        let (asyncBytes, response) = try await session.bytes(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed(NSError(domain: "HTTP", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Download request failed"]))
        }

        let expectedLength = resolveExpectedLength(
            contentLength: httpResponse.expectedContentLength,
            assetSize: assetSize
        )
        if expectedLength == nil {
            onProgress(nil) // indeterminate — no total to divide by
        }

        // Stream to disk via file handle
        FileManager.default.createFile(atPath: destinationURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: destinationURL)
        defer { try? fileHandle.close() }

        let chunkSize = 65_536 // 64KB chunks for progress updates
        var buffer = Data()
        buffer.reserveCapacity(chunkSize)
        var totalWritten: Int64 = 0

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= chunkSize {
                try fileHandle.write(contentsOf: buffer)
                totalWritten += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if let fraction = progressFraction(totalWritten: totalWritten, expectedLength: expectedLength) {
                    onProgress(fraction)
                }
            }
        }

        // Write remaining bytes
        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
            totalWritten += Int64(buffer.count)
        }

        guard isDownloadSizeValid(written: totalWritten, assetSize: assetSize) else {
            throw UpdateError.sizeMismatch(expected: assetSize, received: totalWritten)
        }
    }

    /// Effective denominator for progress: prefer the HTTP content length,
    /// fall back to the published asset size, nil when neither is known.
    nonisolated static func resolveExpectedLength(contentLength: Int64, assetSize: Int64) -> Int64? {
        if contentLength > 0 { return contentLength }
        if assetSize > 0 { return assetSize }
        return nil
    }

    /// Progress fraction clamped to 1.0; nil when the total is unknown.
    nonisolated static func progressFraction(totalWritten: Int64, expectedLength: Int64?) -> Double? {
        guard let expectedLength, expectedLength > 0 else { return nil }
        return min(Double(totalWritten) / Double(expectedLength), 1.0)
    }

    /// A download is complete when the asset size is unknown or matches exactly.
    nonisolated static func isDownloadSizeValid(written: Int64, assetSize: Int64) -> Bool {
        assetSize <= 0 || written == assetSize
    }

    /// Mount the downloaded DMG without blocking the main actor
    func mountDMG(at url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            try await UpdateService.attachDMG(at: url)
        }.value
    }

    /// Off-main hdiutil worker: termination handler + continuation instead
    /// of a blocking waitUntilExit. Non-zero exit throws with stderr text.
    nonisolated private static func attachDMG(at url: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["attach", url.path, "-autoopen"]

        let pipe = Pipe()
        process.standardError = pipe

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorMessage = stderrText.isEmpty
                        ? "hdiutil exited with status \(process.terminationStatus)"
                        : stderrText
                    continuation.resume(throwing: UpdateError.mountFailed(errorMessage))
                }
            }
            do {
                try process.run()
            } catch {
                // run() threw → the process never launched, so the
                // termination handler can never fire; safe to resume here.
                process.terminationHandler = nil
                continuation.resume(throwing: UpdateError.mountFailed(error.localizedDescription))
            }
        }
    }

    /// Open the website download page (fallback when DMG not found)
    func openWebsiteDownload() {
        if let url = URL(string: websiteURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
