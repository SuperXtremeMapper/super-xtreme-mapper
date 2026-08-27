//
//  MappingTransferable.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Custom UTType for Mapping Entries

extension UTType {
    /// Custom UTType for mapping entry data during drag and drop
    nonisolated static var mappingEntry: UTType {
        UTType(exportedAs: "com.superxtrememapping.mapping-entry")
    }

    /// Ordered mapping batch used by native table Copy/Paste commands.
    nonisolated static var mappingBatch: UTType {
        UTType(exportedAs: "com.superxtrememapping.mapping-batch")
    }
}

// MARK: - Ordered Mapping Batch Codec

enum MappingBatchCodecError: Error, Equatable {
    case noMappingBatchProvider
    case providerReturnedNoData
}

enum MappingBatchCodec {
    nonisolated static func encode(_ mappings: [MappingEntry]) throws -> Data {
        try JSONEncoder().encode(mappings)
    }

    nonisolated static func decode(_ data: Data) throws -> [MappingEntry] {
        try JSONDecoder().decode([MappingEntry].self, from: data)
    }

    nonisolated static func itemProvider(for mappings: [MappingEntry]) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.mappingBatch.identifier,
            visibility: .all
        ) { completion in
            do {
                completion(try encode(mappings), nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }

    nonisolated static func load(from providers: [NSItemProvider]) async throws -> [MappingEntry] {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.mappingBatch.identifier)
        }) else {
            throw MappingBatchCodecError.noMappingBatchProvider
        }

        let data = try await loadData(from: provider)
        return try decode(data)
    }

    nonisolated private static func loadData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.mappingBatch.identifier
            ) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: MappingBatchCodecError.providerReturnedNoData
                    )
                }
            }
        }
    }
}

// MARK: - Transferable Conformance

extension MappingEntry: Transferable {
    /// Transfer representation for drag and drop operations
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mappingEntry)
    }
}

// MARK: - Drag Preview

/// A preview view shown during drag operations with warm amber styling
struct MappingDragPreview: View {
    let entry: MappingEntry
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.ioType == .input ? "arrow.down" : "arrow.up")
                .foregroundColor(entry.ioType == .input ? AppThemeV2.Colors.inputBadge : AppThemeV2.Colors.outputBadge)
                .fontWeight(.semibold)

            Text(entry.commandName)
                .lineLimit(1)
                .fontWeight(.medium)

            if count > 1 {
                Text("+\(count - 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppThemeV2.Colors.amber)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppThemeV2.Colors.stone800)
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .stroke(AppThemeV2.Colors.amber.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(AppThemeV2.Radius.md)
        .shadow(color: AppThemeV2.Colors.amber.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}
