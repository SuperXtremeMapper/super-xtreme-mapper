import Foundation

struct MappingReferenceGuide: Sendable {
    let title: String
    let revision: String
    let sections: [Section]

    struct Section: Sendable {
        let heading: String
        let paragraphs: [String]

        nonisolated init(heading: String, paragraphs: [String]) {
            self.heading = heading
            self.paragraphs = paragraphs
        }
    }

    nonisolated init(title: String, revision: String, sections: [Section]) {
        self.title = title
        self.revision = revision
        self.sections = sections
    }

    nonisolated static func build(snapshot: MappingExplanationSnapshot) throws -> Self {
        try Task.checkCancellation()
        var sections = [Section(
            heading: "Reference guide",
            paragraphs: [
                list("Document limitations", snapshot.limitations)
            ]
        )]

        let knownDeviceIDs = Set(snapshot.devices.map(\.id))
        var rowsByDevice: [UUID: [ExplanationRow]] = [:]
        var orphanRows: [ExplanationRow] = []
        for row in snapshot.rows {
            try Task.checkCancellation()
            if knownDeviceIDs.contains(row.deviceID) {
                rowsByDevice[row.deviceID, default: []].append(row)
            } else {
                orphanRows.append(row)
            }
        }
        for (deviceIndex, device) in snapshot.devices.enumerated() {
            try Task.checkCancellation()
            var paragraphs = [
                "Device ID: \(device.id.uuidString)",
                "Name: \(device.name)",
                "Comment: \(value(device.comment))",
                "Profile: \(value(device.profile))",
                list("Settings", device.settings),
                list("Limitations", device.limitations)
            ]
            let rows = rowsByDevice[device.id] ?? []
            if rows.isEmpty {
                paragraphs.append("Mapping rows: None")
            } else {
                paragraphs.append(contentsOf: try rows.map { row in
                    try Task.checkCancellation()
                    return rowParagraph(row)
                })
            }
            sections.append(Section(
                heading: "Device \(deviceIndex + 1): \(device.name)",
                paragraphs: paragraphs
            ))
        }

        if !orphanRows.isEmpty {
            sections.append(Section(
                heading: "Rows with unknown devices",
                paragraphs: try orphanRows.map { row in
                    try Task.checkCancellation()
                    return rowParagraph(row)
                }
            ))
        }

        return Self(title: snapshot.title, revision: snapshot.revision, sections: sections)
    }

    nonisolated var markdown: String {
        let identity = "# \(escapeMarkdown(title))\n\nRevision: \(escapeMarkdown(revision))"
        let content = sections.map { section in
            let body = section.paragraphs.map { paragraph in
                paragraph.components(separatedBy: .newlines)
                    .map(escapeMarkdown)
                    .joined(separator: "  \n")
            }.joined(separator: "\n\n")
            return "## \(escapeMarkdown(section.heading))\n\n\(body)"
        }.joined(separator: "\n\n")
        return "\(identity)\n\n\(content)\n"
    }

    nonisolated var plainText: String {
        let identity = "\(title)\nRevision: \(revision)"
        let content = sections.map { section in
            "\(section.heading)\n\n\(section.paragraphs.joined(separator: "\n\n"))"
        }.joined(separator: "\n\n")
        return "\(identity)\n\n\(content)\n"
    }

    nonisolated private static func rowParagraph(_ row: ExplanationRow) -> String {
        [
            "Row \(row.position)",
            "Row ID: \(row.id.uuidString)",
            "Device ID: \(row.deviceID.uuidString)",
            "Device: \(value(row.deviceName))",
            "Command ID: \(row.commandID)",
            "Command: \(value(row.command))",
            "Direction: \(value(row.direction))",
            "Assignment: \(value(row.assignment))",
            "MIDI: \(value(row.midi))",
            "Controller type: \(value(row.controllerType))",
            "Interaction: \(value(row.interaction))",
            list("Conditions", row.conditions),
            list("Modifier reads", row.modifierReads.map(String.init)),
            list("Modifier writes", row.modifierWrites.map(String.init)),
            list("Details and feedback", row.details),
            list("Physical controls", row.controls),
            list("Sources", row.sources),
            list("Limitations", row.limitations),
            "Comment: \(value(row.comment))"
        ].joined(separator: "\n")
    }

    nonisolated private static func list(_ label: String, _ values: [String]) -> String {
        "\(label): \(values.isEmpty ? "None" : values.joined(separator: "; "))"
    }

    nonisolated private static func value(_ string: String) -> String {
        string.isEmpty ? "None" : string
    }

    nonisolated private func escapeMarkdown(_ string: String) -> String {
        var result = ""
        let markdownCharacters = CharacterSet(charactersIn: "\\`*_{}[]()#+!><|~")
        for scalar in string.unicodeScalars {
            if markdownCharacters.contains(scalar) {
                result.append("\\")
            }
            result.append(Character(scalar))
        }
        return result
    }
}
