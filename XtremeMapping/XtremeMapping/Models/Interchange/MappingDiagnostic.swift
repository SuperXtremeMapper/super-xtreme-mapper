import Foundation

nonisolated enum MappingDiagnosticSeverity: String, Codable, Sendable { case error, warning, information }

nonisolated struct MappingDiagnostic: Identifiable, Sendable {
    let id: UUID
    let code: String
    let severity: MappingDiagnosticSeverity
    let path: String
    let deviceID: UUID?
    let mappingID: UUID?
    let message: String
    let suggestion: String?

    init(id: UUID = UUID(), code: String, severity: MappingDiagnosticSeverity, path: String,
         deviceID: UUID? = nil, mappingID: UUID? = nil, message: String, suggestion: String? = nil) {
        self.id = id; self.code = code; self.severity = severity; self.path = path
        self.deviceID = deviceID; self.mappingID = mappingID; self.message = message; self.suggestion = suggestion
    }
}

/// A value snapshot; review never retains or mutates an open document.
nonisolated struct JSONImportCandidate: Sendable {
    let mappingFile: MappingFile?
    let diagnostics: [MappingDiagnostic]
    let canOpen: Bool
    let canWriteTSI: Bool
}
