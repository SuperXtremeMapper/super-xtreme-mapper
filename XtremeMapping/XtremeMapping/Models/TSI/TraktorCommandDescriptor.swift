//
//  TraktorCommandDescriptor.swift
//  XtremeMapping
//

import Foundation

/// A catalog entry together with the evidence available for creating it.
struct TraktorCommandDescriptor: Identifiable, Hashable, Sendable {
    enum Verification: String, Codable, Hashable, Sendable {
        case verifiedTraktor441
        case legacy
        case unknown
    }

    let id: Int
    let name: String
    let verification: Verification
    let supportedDirections: Set<IODirection>

    func supports(_ direction: IODirection) -> Bool {
        switch direction {
        case .input, .output:
            return supportedDirections.contains(direction)
        case .all:
            return supportedDirections.isSuperset(of: [.input, .output])
        }
    }
}
