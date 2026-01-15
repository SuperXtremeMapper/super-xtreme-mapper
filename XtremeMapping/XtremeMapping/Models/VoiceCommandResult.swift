//
//  VoiceCommandResult.swift
//  XtremeMapping
//
//  Response model for Claude API voice command interpretation.
//

import Foundation

/// Represents a single alternative command suggestion for disambiguation.
///
/// Used when Claude returns multiple possible interpretations of a voice command,
/// or when building the disambiguation UI from the top result plus alternatives.
struct CommandAlternative: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for SwiftUI list rendering
    var id: String { "\(command)-\(assignment ?? "none")-\(confidence)" }

    /// The Traktor command name (e.g., "Deck Volume", "Play/Pause")
    let command: String

    /// The target assignment (e.g., "Deck A", "FX Unit 2", "Global")
    let assignment: String?

    /// Brief explanation for the disambiguation UI
    let description: String

    /// Confidence level from 0.0 to 1.0
    let confidence: Double
}

/// Represents the result of Claude API interpreting a voice command.
///
/// Contains the primary match along with confidence scoring and
/// alternative suggestions for disambiguation when confidence is low.
struct VoiceCommandResult: Codable, Sendable {
    /// The Traktor command name that best matches the voice input (e.g., "Deck Volume")
    let command: String

    /// The target assignment inferred from the voice command (e.g., "Deck B", "FX Unit 1")
    let assignment: String?

    /// The controller type if inferrable from context (e.g., "Fader", "Button", "Encoder")
    let controllerType: String?

    /// Confidence level from 0.0 to 1.0
    let confidence: Double

    /// Top 3-5 alternative interpretations for disambiguation when confidence is low
    let alternatives: [CommandAlternative]?
}

// MARK: - Helpers

extension VoiceCommandResult {
    /// Converts this result to a CommandAlternative for use in disambiguation UI.
    ///
    /// This allows presenting the primary result alongside its alternatives
    /// in a unified list format.
    var asAlternative: CommandAlternative {
        CommandAlternative(
            command: command,
            assignment: assignment,
            description: descriptionForDisambiguation,
            confidence: confidence
        )
    }

    /// Generates a human-readable description for disambiguation UI.
    private var descriptionForDisambiguation: String {
        var parts: [String] = []

        if let assignment = assignment {
            parts.append("Assigned to \(assignment)")
        }

        if let controllerType = controllerType {
            parts.append("(\(controllerType))")
        }

        if parts.isEmpty {
            return "Best match for your voice command"
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - High Confidence Check

extension VoiceCommandResult {
    /// The confidence threshold above which automatic mapping is created
    /// without showing disambiguation UI.
    static let highConfidenceThreshold: Double = 0.85

    /// Whether the confidence is high enough to create a mapping automatically.
    var isHighConfidence: Bool {
        confidence > Self.highConfidenceThreshold
    }
}
