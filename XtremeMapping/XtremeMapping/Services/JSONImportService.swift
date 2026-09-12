import Foundation

nonisolated enum JSONImportService {
    static func review(_ data: Data) -> JSONImportCandidate {
        do {
            let document = try SXMJSONCodec.document(from: data)
            guard document.format == "sxm-mapping", [1, 2].contains(document.schemaVersion) else {
                throw SXMJSONIssue(code: "schema.version", path: "$.schemaVersion", message: "Expected sxm-mapping schema version 1 or 2. Export with a compatible SXM version.")
            }
            let source = try document.preservation?.reconstruct()
            var diagnostics = MappingValidationService.validate(document, source: source)
            if diagnostics.contains(where: { $0.severity == .error }) {
                return JSONImportCandidate(mappingFile: nil, diagnostics: diagnostics, canOpen: false, canWriteTSI: false)
            }
            let file = try SXMJSONCodec.mappingFile(from: document, reconstructedSource: source)
            let canWrite: Bool
            do {
                let plan = try TSIWriter().makeWritePlan(for: file)
                if plan.disposition == .regenerated {
                    diagnostics += try normalizationDiagnostics(file, output: plan.output)
                }
                canWrite = true
                diagnostics.append(MappingDiagnostic(code: "preservation.ready", severity: .information, path: "$",
                    message: file.sourceEnvelope == nil ? "Source-free mapping: TSI will contain modeled data only."
                        : "Original TSI source is retained and ordinary TSI output passed preservation checks."))
            } catch {
                canWrite = false
                let inspectionOnly = file.sourceEnvelope != nil && error is TSIPreservationError
                diagnostics.append(MappingDiagnostic(code: inspectionOnly ? "preservation.writeBlocked" : "writer.invalid",
                    severity: inspectionOnly ? .warning : .error, path: "$", message: error.localizedDescription,
                    suggestion: inspectionOnly ? "Open for inspection, or revert unsupported edits before saving TSI. No source data has been discarded."
                        : "Correct the mapping and import again."))
            }
            let canOpen = !diagnostics.contains { $0.severity == .error }
            return JSONImportCandidate(mappingFile: canOpen ? file : nil, diagnostics: diagnostics, canOpen: canOpen, canWriteTSI: canWrite)
        } catch {
            let issue = error as? SXMJSONIssue
            let offset = issue?.byteOffset.map { " (UTF-8 byte \($0))" } ?? ""
            let diagnostic = MappingDiagnostic(code: issue?.code ?? "schema.invalid", severity: .error,
                path: issue?.path ?? "$", message: (issue?.message ?? error.localizedDescription) + offset,
                suggestion: "Correct this field in the JSON file and import again.")
            return JSONImportCandidate(mappingFile: nil, diagnostics: [diagnostic], canOpen: false, canWriteTSI: false)
        }
    }

    /// Canonical writing can apply command defaults. Surface the actual changed
    /// projection so accepting a successful preflight never silently accepts them.
    private static func normalizationDiagnostics(_ file: MappingFile, output: Data) throws -> [MappingDiagnostic] {
        let reparsed = try TSIParser().parseDocument(output)
        guard reparsed.devices.count == file.devices.count,
              zip(reparsed.devices, file.devices).allSatisfy({ $0.mappings.count == $1.mappings.count }) else {
            throw SXMJSONIssue(code: "writer.rowLoss", path: "$.devices", message: "TSI generation changed device or mapping counts; this import cannot be written safely.")
        }
        var issues: [MappingDiagnostic] = []
        if file.version != reparsed.version {
            issues.append(MappingDiagnostic(code: "writer.normalization", severity: .warning, path: "$.tsiVersion",
                message: "TSI writing normalizes tsiVersion: \(file.version) → \(reparsed.version).",
                suggestion: "This is the runtime version field, not a Traktor application version. Cancel if this change is not intended."))
        }
        let encoder = JSONEncoder()
        for (di, pair) in zip(file.devices, reparsed.devices).enumerated() {
            let (before, after) = pair
            let deviceFields = [("name", before.name, after.name), ("inPort", before.inPort, after.inPort), ("outPort", before.outPort, after.outPort)]
                .filter { $0.1 != $0.2 }.map { "\($0.0): \(displayValue($0.1)) → \(displayValue($0.2))" }
            if !deviceFields.isEmpty {
                issues.append(MappingDiagnostic(code: "writer.normalization", severity: .warning, path: "$.devices[\(di)]",
                    deviceID: before.id, message: "TSI writing applies defaults to: \(deviceFields.joined(separator: ", ")).",
                    suggestion: "Supply explicit device and port names if these defaults are not intended."))
            }
            for (mi, rows) in zip(before.mappings, after.mappings).enumerated() {
                let a = try JSONSerialization.jsonObject(with: encoder.encode(SXMJSONMapping(rows.0))) as! [String: Any]
                let b = try JSONSerialization.jsonObject(with: encoder.encode(SXMJSONMapping(rows.1.copy(withID: rows.0.id)))) as! [String: Any]
                let changed = Set(a.keys).union(b.keys).sorted().filter { key in
                    !NSDictionary(dictionary: ["value": a[key] ?? NSNull()]).isEqual(to: ["value": b[key] ?? NSNull()])
                }
                if !changed.isEmpty {
                    let changes = changed.map { "\($0): \(displayValue(a[$0])) → \(displayValue(b[$0]))" }
                    issues.append(MappingDiagnostic(code: "writer.normalization", severity: .warning,
                        path: "$.devices[\(di)].mappings[\(mi)]", deviceID: before.id, mappingID: rows.0.id,
                        message: "TSI writing normalizes these fields: \(changes.joined(separator: "; ")).",
                        suggestion: "These command defaults will be used in the saved TSI. Cancel if they do not match your intended edit."))
                }
            }
        }
        return issues
    }

    private static func displayValue(_ value: Any?) -> String {
        guard let value else { return "omitted" }
        if let text = value as? String {
            let shortened = String(decoding: text.utf8.prefix(160), as: UTF8.self)
            return "\"" + shortened + (text.utf8.count > 160 ? "…" : "") + "\""
        }
        guard let bytes = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]) else { return "unknown" }
        return String(decoding: bytes.prefix(160), as: UTF8.self) + (bytes.count > 160 ? "…" : "")
    }

}
