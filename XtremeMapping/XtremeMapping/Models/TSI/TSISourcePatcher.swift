import Foundation

/// A deliberately narrow edit path: existing row comments and row order only.
/// Unknown bytes are copied, never interpreted or regenerated. Unsupported
/// source layouts fall back to the writer's existing preservation refusal.
struct TSISourcePatcher {
    private enum Unsupported: Error { case source }
    private let parser = TSIParser()
    private let writer = TSIWriter()

    func patch(_ file: MappingFile) throws -> Data? {
        guard let source = file.sourceEnvelope,
              !source.baseline.matches(file),
              source.controllerValues.count == 1,
              source.baseline.version == file.version,
              source.baseline.devices.count == file.devices.count else { return nil }
        let allowed: Set<TSIPreservationRisk.Code> = [
            .unknownFrame, .unusedMIDIDefinition, .noncanonicalDDIF,
            .noncanonicalDIOI, .extraXMLEntry,
        ]
        guard source.risks.allSatisfy({ allowed.contains($0.code) }) else { return nil }
        for (old, new) in zip(source.baseline.devices, file.devices) {
            var metadata = new
            metadata.mappings = old.mappings
            guard metadata == old,
                  Set(old.mappings.map(\.id)).count == old.mappings.count,
                  Set(new.mappings.map(\.id)) == Set(old.mappings.map(\.id)),
                  new.mappings.count == old.mappings.count else { return nil }
            let originals = Dictionary(uniqueKeysWithValues: old.mappings.map { ($0.id, $0) })
            for row in new.mappings {
                guard let original = originals[row.id], row.importedCMAD != nil else { return nil }
                var compared = row
                compared.comment = original.comment
                guard compared == original else { return nil }
            }
        }
        do {
            let roots = source.primaryFrames
            guard roots.filter({ $0.identifier == "DIOM" }).count == 1 else { return nil }
            let updated = try roots.map { frame in
                guard frame.identifier == "DIOM" else { return frame }
                return try replacingChild(frame, name: "DEVS") { devs in
                    guard devs.data.count >= 4,
                          Int(read32(devs.data, 0)) == file.devices.count else { throw Unsupported.source }
                    let devices = try parser.parseFrames(from: Data(devs.data.dropFirst(4)))
                    guard devices.count == file.devices.count,
                          devices.allSatisfy({ $0.identifier == "DEVI" }) else { throw Unsupported.source }
                    let patched = try devices.enumerated().map { index, device in
                        try patchDevice(device, old: source.baseline.devices[index], new: file.devices[index])
                    }
                    return self.frame("DEVS", Data(devs.data.prefix(4)) + writer.encodeFrames(patched))
                }
            }
            return try replaceControllerValue(in: source, binary: writer.encodeFrames(updated))
        } catch is Unsupported {
            return nil
        }
    }

    private func patchDevice(_ device: TSIFrame, old: Device, new: Device) throws -> TSIFrame {
        guard device.data.count >= 4 else { throw Unsupported.source }
        let prefix = 4 + Int(read32(device.data, 0)) * 2
        guard prefix <= device.data.count else { throw Unsupported.source }
        let children = try parser.parseFrames(from: Data(device.data.dropFirst(prefix)))
        guard children.count == 1, children[0].identifier == "DDAT" else { throw Unsupported.source }
        let ddat = try replacingChild(children[0], name: "DDCB") { ddcb in
            try replacingChild(ddcb, name: "CMAS") { cmas in
                guard cmas.data.count >= 4,
                      Int(read32(cmas.data, 0)) == old.mappings.count else { throw Unsupported.source }
                let rows = try parser.parseFrames(from: Data(cmas.data.dropFirst(4)))
                guard rows.count == old.mappings.count,
                      rows.allSatisfy({ $0.identifier == "CMAI" }) else { throw Unsupported.source }
                let indexed = Dictionary(uniqueKeysWithValues: old.mappings.enumerated().map { ($0.element.id, $0.offset) })
                let patched = try new.mappings.map { row -> TSIFrame in
                    guard let index = indexed[row.id] else { throw Unsupported.source }
                    let original = rows[index]
                    guard original.data.count >= 20,
                          read32(original.data, 8) == UInt32(old.mappings[index].commandID) else { throw Unsupported.source }
                    let settings = try parser.parseFrames(from: Data(original.data.dropFirst(12)))
                    guard settings.count == 1, settings[0].identifier == "CMAD" else { throw Unsupported.source }
                    guard row.comment != old.mappings[index].comment else { return original }
                    let payload = settings[0].data
                    guard payload.count >= 52 else { throw Unsupported.source }
                    let commentEnd = 52 + Int(read32(payload, 48)) * 2
                    guard commentEnd <= payload.count else { throw Unsupported.source }
                    let updated = Data(payload.prefix(48)) + wide(row.comment) + Data(payload.dropFirst(commentEnd))
                    return frame("CMAI", Data(original.data.prefix(12)) + writer.encodeFrames([frame("CMAD", updated)]))
                }
                return frame("CMAS", Data(cmas.data.prefix(4)) + writer.encodeFrames(patched))
            }
        }
        return frame("DEVI", Data(device.data.prefix(prefix)) + writer.encodeFrames([ddat]))
    }

    /// Replace one child at a known structural position; never search opaque payloads.
    private func replacingChild(
        _ parent: TSIFrame, name: String, transform: (TSIFrame) throws -> TSIFrame
    ) throws -> TSIFrame {
        let children = try parser.parseFrames(from: parent.data)
        guard children.filter({ $0.identifier == name }).count == 1 else { throw Unsupported.source }
        return frame(parent.identifier, try writer.encodeFrames(children.map {
            $0.identifier == name ? try transform($0) : $0
        }))
    }

    private func replaceControllerValue(in source: TSIRawEnvelope, binary: Data) throws -> Data {
        // Only the exact, unique literal Value attribute is supported. Entity-
        // encoded attributes and nonstandard XML are intentionally ineligible.
        guard let text = String(data: source.originalXML, encoding: .utf8) else { throw Unsupported.source }
        let entryPattern = #"<Entry\s+[^<>]*>"#
        let entries = try NSRegularExpression(pattern: entryPattern)
        let name = try NSRegularExpression(pattern: #"\bName\s*=\s*(["'])DeviceIO\.Config\.Controller\1"#)
        let value = try NSRegularExpression(pattern: #"\bValue\s*=\s*(["'])([^"']*)\1"#)
        let whole = NSRange(text.startIndex..., in: text)
        var ranges: [NSRange] = []
        for entry in entries.matches(in: text, range: whole) {
            guard name.numberOfMatches(in: text, range: entry.range) == 1 else { continue }
            let values = value.matches(in: text, range: entry.range)
            guard values.count == 1,
                  let range = Range(values[0].range(at: 2), in: text),
                  String(text[range]) == source.controllerValues[0] else { throw Unsupported.source }
            ranges.append(values[0].range(at: 2))
        }
        guard ranges.count == 1, let range = Range(ranges[0], in: text) else { throw Unsupported.source }
        let output = Data(text.replacingCharacters(in: range, with: binary.base64EncodedString()).utf8)
        let scan = try parser.scanXML(output)
        guard scan.controllerValues == [binary.base64EncodedString()] else { throw Unsupported.source }
        return output
    }

    private func frame(_ id: String, _ data: Data) -> TSIFrame {
        TSIFrame(identifier: id, size: UInt32(data.count), data: data)
    }

    private func read32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian }
    }

    private func wide(_ text: String) -> Data {
        var count = UInt32(text.utf16.count).bigEndian
        var result = Data(bytes: &count, count: 4)
        for unit in text.utf16 {
            var encoded = unit.bigEndian
            result.append(Data(bytes: &encoded, count: 2))
        }
        return result
    }
}
