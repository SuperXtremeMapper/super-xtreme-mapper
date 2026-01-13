//
//  XtremeMappingDocument.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var tsi: UTType {
        UTType(exportedAs: "com.native-instruments.traktor.tsi")
    }
}

struct TraktorMappingDocument: FileDocument {
    var mappingFile: MappingFile

    static var readableContentTypes: [UTType] { [.tsi] }

    init(mappingFile: MappingFile = MappingFile()) {
        self.mappingFile = mappingFile
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // For now, create empty MappingFile - full parsing comes later
        // TODO: Parse TSI data using TSIParser
        _ = data // Suppress unused warning
        self.mappingFile = MappingFile()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // TODO: Serialize using TSIWriter
        // For now, return empty data
        return FileWrapper(regularFileWithContents: Data())
    }
}
