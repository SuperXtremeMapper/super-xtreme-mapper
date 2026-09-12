import SwiftUI

struct JSONImportReviewSheet: View {
    @ObservedObject var coordinator: JSONImportCoordinator
    let fileName: String
    @State private var severityFilter = "All"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review JSON Import").font(.title2.weight(.semibold))
                Text(fileName).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            if coordinator.isWorking {
                ProgressView("Reading and checking mappings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = coordinator.errorMessage {
                Label("Unable to review this file", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                ScrollView { Text(error).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            } else if let candidate = coordinator.candidate {
                review(candidate)
            }
            Divider()
            HStack {
                Text("Opens a new untitled TSI document.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: coordinator.cancel).keyboardShortcut(.cancelAction)
                Button(coordinator.candidate?.canWriteTSI == false && coordinator.candidate?.canOpen == true ? "Open for Inspection" : "Import", action: coordinator.accept)
                    .keyboardShortcut(.defaultAction)
                    .disabled(coordinator.isWorking || coordinator.candidate?.canOpen != true || coordinator.candidate?.diagnostics.contains(where: { $0.severity == .error }) == true)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .tint(AppThemeV2.Colors.amber)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func review(_ candidate: JSONImportCandidate) -> some View {
        if let file = candidate.mappingFile {
            Text("\(file.devices.count) devices · \(file.allMappings.count) mappings")
                .font(.headline)
            if let envelope = file.sourceEnvelope {
                Text("Original TSI source retained.").font(.callout)
                Text(changeSummary(file, baseline: envelope.baseline))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No original TSI source: only the modeled mapping data is available.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !candidate.canWriteTSI {
                Label("Inspection only. These mappings cannot currently be saved as a TSI. Review the issues below before editing.", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        HStack {
            Text("\(candidate.diagnostics.filter { $0.severity == .error }.count) errors · \(candidate.diagnostics.filter { $0.severity == .warning }.count) warnings")
                .font(.callout.weight(.medium))
            Spacer()
            Picker("Show issues", selection: $severityFilter) {
                Text("All").tag("All")
                Text("Errors").tag("error")
                Text("Warnings").tag("warning")
            }.labelsHidden().frame(width: 130)
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                let issues = candidate.diagnostics.filter { severityFilter == "All" || $0.severity.rawValue == severityFilter }
                if issues.isEmpty {
                    Text(candidate.diagnostics.isEmpty ? "No issues found." : "No matching issues.")
                        .foregroundStyle(.secondary)
                }
                ForEach(issues) { diagnostic in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(diagnostic.severity.rawValue.capitalized, systemImage: diagnostic.severity == .error ? "xmark.octagon" : diagnostic.severity == .warning ? "exclamationmark.triangle" : "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(diagnostic.severity == .error ? Color.red : diagnostic.severity == .warning ? Color.orange : Color.secondary)
                        Text(diagnostic.message).font(.callout).fixedSize(horizontal: false, vertical: true)
                        Text(diagnostic.path).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        if let mappingID = diagnostic.mappingID { Text("Mapping \(mappingID.uuidString)").font(.caption2).foregroundStyle(.secondary) }
                        if let suggestion = diagnostic.suggestion { Text(suggestion).font(.caption).fixedSize(horizontal: false, vertical: true) }
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    private func changeSummary(_ file: MappingFile, baseline: TSISemanticBaseline) -> String {
        let old = Dictionary(baseline.devices.flatMap(\.mappings).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let current = Dictionary(file.allMappings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let added = current.keys.filter { old[$0] == nil }.count
        let removed = old.keys.filter { current[$0] == nil }.count
        let changed = current.values.filter { row in old[row.id].map { $0 != row } ?? false }.count
        return "Compared with source: \(added) added · \(removed) removed · \(changed) changed mappings"
    }
}
