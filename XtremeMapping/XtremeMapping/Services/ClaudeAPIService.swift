//
//  ClaudeAPIService.swift
//  XtremeMapping
//
//  Service for interpreting voice commands using Claude API.
//

import Foundation

/// Service for interpreting voice commands using the Claude API.
///
/// Sends transcribed speech along with the available Traktor commands
/// to Claude for interpretation, returning structured results with
/// confidence scores and alternatives for disambiguation.
final class ClaudeAPIService: Sendable {

    // MARK: - Types

    /// Errors that can occur during Claude API operations
    enum ClaudeError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case networkError(Error)
        case invalidResponse(Int)
        case decodingError(Error)
        case noContentInResponse
        case jsonExtractionFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No API key configured. Please add your Anthropic API key in Settings."
            case .invalidURL:
                return "Invalid API URL configuration."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse(let statusCode):
                return "API returned error status: \(statusCode)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .noContentInResponse:
                return "No content in API response."
            case .jsonExtractionFailed:
                return "Could not extract JSON from Claude's response."
            }
        }
    }

    // MARK: - Configuration

    /// Claude API endpoint
    private static let apiEndpoint = "https://api.anthropic.com/v1/messages"

    /// Model to use - Haiku for speed and cost efficiency (~$0.003 per request)
    private static let model = "claude-3-haiku-20240307"

    /// API version header
    private static let apiVersion = "2023-06-01"

    /// Maximum tokens for response
    private static let maxTokens = 1024

    // MARK: - Properties

    /// API key provider - will be replaced with APIKeyManager in Task 6
    private let apiKeyProvider: @Sendable () -> String?

    /// URL session for network requests
    private let session: URLSession

    // MARK: - Initialization

    /// Initialize with an API key provider closure.
    ///
    /// The provider closure allows deferred API key lookup, enabling integration
    /// with APIKeyManager once implemented (Task 6).
    ///
    /// - Parameter apiKeyProvider: Closure that returns the current API key, or nil if not configured.
    init(apiKeyProvider: @escaping @Sendable () -> String?) {
        self.apiKeyProvider = apiKeyProvider
        self.session = URLSession.shared
    }

    /// Convenience initializer with a static API key.
    ///
    /// Useful for testing or when the API key is known at initialization time.
    ///
    /// - Parameter apiKey: The Anthropic API key to use.
    convenience init(apiKey: String) {
        self.init(apiKeyProvider: { apiKey })
    }

    // MARK: - Public API

    /// Interprets a voice command transcript using Claude API.
    ///
    /// Sends the transcript along with available Traktor commands to Claude,
    /// which identifies the most likely command match, assignment, and controller type.
    ///
    /// - Parameters:
    ///   - transcript: The transcribed voice command (e.g., "control the volume on Deck B")
    ///   - availableCommands: List of valid Traktor command names to match against
    /// - Returns: A `VoiceCommandResult` with the best match and alternatives
    /// - Throws: `ClaudeError` if the API call fails
    func interpretCommand(
        transcript: String,
        availableCommands: [String]
    ) async throws -> VoiceCommandResult {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        guard let url = URL(string: Self.apiEndpoint) else {
            throw ClaudeError.invalidURL
        }

        let prompt = buildPrompt(transcript: transcript, commands: availableCommands)
        let request = try buildRequest(url: url, apiKey: apiKey, prompt: prompt)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse(0)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClaudeError.invalidResponse(httpResponse.statusCode)
        }

        return try parseResponse(data)
    }

    // MARK: - Private Methods

    /// Builds the prompt for Claude with the voice transcript and command list.
    private func buildPrompt(transcript: String, commands: [String]) -> String {
        let commandList = commands.joined(separator: ", ")

        return """
        You are a Traktor DJ mapping assistant. Given a voice command, identify:
        1. The Traktor command name (from the provided list)
        2. The target assignment (Deck A/B/C/D, FX Unit 1-4, Global, etc.)
        3. The controller type (Button, Fader, Encoder) if inferrable from context
        4. Your confidence level (0.0 to 1.0)

        Available commands: \(commandList)

        User said: "\(transcript)"

        Respond ONLY with valid JSON in this exact format (no other text):
        {
            "command": "exact command name from list",
            "assignment": "Deck A" or "FX Unit 1" or null if unclear,
            "controllerType": "Fader" or "Button" or "Encoder" or null if unclear,
            "confidence": 0.95,
            "alternatives": [
                {
                    "command": "alternative command name",
                    "assignment": "Deck B" or null,
                    "description": "Brief explanation why this might be the intent",
                    "confidence": 0.7
                }
            ]
        }

        Include up to 5 alternatives if there are other plausible interpretations.
        Use null (not "null") for optional fields that cannot be determined.
        """
    }

    /// Builds the HTTP request for the Claude API.
    private func buildRequest(url: URL, apiKey: String, prompt: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": Self.maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Performs the network request.
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw ClaudeError.networkError(error)
        }
    }

    /// Parses Claude's response and extracts the VoiceCommandResult.
    private func parseResponse(_ data: Data) throws -> VoiceCommandResult {
        // First, parse the Claude API response structure
        let claudeResponse: ClaudeAPIResponse
        do {
            claudeResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
        } catch {
            throw ClaudeError.decodingError(error)
        }

        // Extract the text content from Claude's response
        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" }),
              let text = textContent.text else {
            throw ClaudeError.noContentInResponse
        }

        // Extract JSON from the text (Claude might include markdown code blocks)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeError.jsonExtractionFailed
        }

        // Decode the VoiceCommandResult from the extracted JSON
        do {
            return try JSONDecoder().decode(VoiceCommandResult.self, from: jsonData)
        } catch {
            throw ClaudeError.decodingError(error)
        }
    }

    /// Extracts JSON from Claude's text response.
    ///
    /// Claude may wrap JSON in markdown code blocks or include explanatory text.
    /// This method finds and extracts the JSON object.
    private func extractJSON(from text: String) -> String {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code block if present
        if cleanText.hasPrefix("```json") {
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            cleanText = String(cleanText.dropFirst(3))
        }

        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }

        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If still not starting with {, try to find the JSON object
        if !cleanText.hasPrefix("{") {
            if let startIndex = cleanText.firstIndex(of: "{"),
               let endIndex = cleanText.lastIndex(of: "}") {
                cleanText = String(cleanText[startIndex...endIndex])
            }
        }

        return cleanText
    }
}

// MARK: - Claude API Response Types

/// Internal response structure from Claude API
private struct ClaudeAPIResponse: Decodable {
    let content: [ContentBlock]
}

/// Content block in Claude API response
private struct ContentBlock: Decodable {
    let type: String
    let text: String?
}
