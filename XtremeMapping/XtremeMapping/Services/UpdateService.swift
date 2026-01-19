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
