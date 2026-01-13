//
//  MappingTransferable.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Custom UTType for Mapping Entries

extension UTType {
    /// Custom UTType for mapping entry data during drag and drop
    static var mappingEntry: UTType {
        UTType(exportedAs: "com.xtrememapping.mapping-entry")
    }
}

// MARK: - Transferable Conformance

extension MappingEntry: Transferable {
    /// Transfer representation for drag and drop operations
    nonisolated static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { entry in
            // Encode to JSON data for transfer
            try JSONEncoder().encode(entry)
        } importing: { data in
            // Decode from JSON data
            try JSONDecoder().decode(MappingEntry.self, from: data)
        }
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
                .foregroundColor(entry.ioType == .input ? AppTheme.inputColor : AppTheme.outputColor)
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
                    .background(AppTheme.accentColor)
                    .foregroundColor(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surfaceColor)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.accentColor.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.accentColor.opacity(0.3), radius: 8, x: 0, y: 2)
    }
}
