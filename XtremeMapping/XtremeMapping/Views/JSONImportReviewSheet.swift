import SwiftUI

struct JSONImportReviewSheet: View {
    @ObservedObject var coordinator: JSONImportCoordinator
    let fileName: String
    @State private var severityFilter = "All"
    @State private var repairConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review JSON Import").font(.system(size: 14, weight: .semibold))
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
            repairControls
            Divider()
            HStack {
                Text("Opens a new untitled TSI document.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: coordinator.cancel).keyboardShortcut(.cancelAction)
                    .buttonStyle(AssistantButtonStyle())
                Button(coordinator.candidate?.canWriteTSI == false && coordinator.candidate?.canOpen == true ? "Open for Inspection" : "Import", action: coordinator.accept)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(AssistantButtonStyle(primary: true))
                    .disabled(coordinator.isWorking || coordinator.isRepairing || coordinator.candidate?.canOpen != true || coordinator.candidate?.diagnostics.contains(where: { $0.severity == .error }) == true)
            }
        }
        .padding(16)
        .background(AppThemeV2.Colors.stone900)
        .frame(minWidth: 520, minHeight: 440)
        .tint(AppThemeV2.Colors.amber)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var repairControls: some View {
        if let plan = coordinator.repairPlan {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(coordinator.isRepairAccepted ? "Repair accepted for import" : "Review proposed repair", systemImage: coordinator.isRepairAccepted ? "checkmark.circle" : "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(plan.patches.count) edits").font(.caption).foregroundStyle(.secondary)
                }
                Text("Exact changes computed locally. Mapping and TSI preservation checks passed. The original file is unchanged.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(plan.patches.enumerated()), id: \.offset) { index, patch in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Edit \(index + 1) · Before").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(patch.before).font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("After").font(.caption.weight(.semibold)).foregroundStyle(AppThemeV2.Colors.amber)
                                Text(patch.after.isEmpty ? "(Removed)" : patch.after).font(.system(size: 11, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.textSelection(.enabled)
                            Divider()
                        }
                    }
                }.frame(minHeight: 90, maxHeight: 180)
                HStack {
                    Button("Discard Repair", action: coordinator.discardRepair).buttonStyle(AssistantButtonStyle())
                    Spacer()
                    if !coordinator.isRepairAccepted {
                        Button("Accept Repair", action: coordinator.acceptRepair).buttonStyle(AssistantButtonStyle(primary: true))
                    } else {
                        Text("Choose Import to open the repaired copy.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12).background(AppThemeV2.Colors.stone800, in: RoundedRectangle(cornerRadius: 6))
        } else if coordinator.isRepairing {
            HStack {
                ProgressView().controlSize(.small)
                Text(coordinator.repairStatus).font(.callout)
                Spacer()
                Button("Stop Repair", action: coordinator.cancelRepair).buttonStyle(AssistantButtonStyle())
            }
        } else if coordinator.candidate?.canOpen == false {
            VStack(alignment: .leading, spacing: 8) {
                if let unavailable = coordinator.repairUnavailableReason {
                    Text(unavailable).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else if coordinator.canRequestRepair {
                    DisclosureGroup("Optional AI repair") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sends mapping JSON, including names and comments, to Anthropic using the stored API key and Claude Sonnet. Retained TSI source stays on this Mac. Charges may apply. Every proposed change is reviewed here before import.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            Toggle("I agree to send this mapping JSON for repair", isOn: $repairConsent)
                                .font(.caption)
                            Button("Send JSON for AI Repair") { coordinator.requestRepair(consent: repairConsent) }
                                .buttonStyle(AssistantButtonStyle(primary: true)).disabled(!repairConsent)
                        }.padding(.top, 6)
                    }.font(.system(size: 12, weight: .medium))
                }
                if let error = coordinator.repairError {
                    Text(error).font(.caption).foregroundStyle(AppThemeV2.Colors.warning)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
        }
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
