//
//  XtremeMappingDocument.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

extension UTType {
    static var tsi: UTType {
        UTType(exportedAs: "com.native-instruments.traktor.tsi")
    }
}

/// Reference-based document that properly tracks changes for save prompts
final class TraktorMappingDocument: ReferenceFileDocument {
    typealias Snapshot = MappingFile

    @Published var mappingFile: MappingFile

    static var readableContentTypes: [UTType] { [.tsi] }

    init(mappingFile: MappingFile = MappingFile()) {
        self.mappingFile = mappingFile
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Parse TSI file
        let parser = TSIParser()

        do {
            // Step 1: Extract Base64-encoded binary data from XML
            let base64String = try TSIParser.extractControllerData(from: data)

            // Step 2: Decode Base64 to binary data
            let binaryData = try parser.decodeBase64(base64String)

            // Step 3: Parse frames from binary data
            let frames = try parser.parseFrames(from: binaryData)

            // Step 4: Interpret frames into mappings
            self.mappingFile = try TSIInterpreter.interpret(frames: frames)

        } catch {
            print("TSI Parser error: \(error)")
            // Fall back to empty file on parse error
            self.mappingFile = MappingFile()
        }
    }

    func snapshot(contentType: UTType) throws -> MappingFile {
        return mappingFile
    }

    func fileWrapper(snapshot: MappingFile, configuration: WriteConfiguration) throws -> FileWrapper {
        let writer = TSIWriter()
        let data = writer.write(snapshot)
        return FileWrapper(regularFileWithContents: data)
    }
}
