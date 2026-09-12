import Foundation
import Combine

nonisolated struct AssistantConversationMessage: Identifiable, Sendable {
    let id: UUID
    let role: String
    let text: String
    let answer: MappingAssistantAnswer?
    let revision: String
    init(id: UUID = UUID(), role: String, text: String, answer: MappingAssistantAnswer? = nil, revision: String) {
        self.id = id; self.role = role; self.text = text; self.answer = answer; self.revision = revision
    }
}
@MainActor final class AssistantConversationCoordinator: ObservableObject {
    @Published private(set) var messages: [AssistantConversationMessage] = []
    @Published private(set) var pendingPlan: AssistantEditPlan?
    @Published private(set) var localContext: ExplanationContext?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    private let service: any AssistantConversing
    private var currentTask: Task<Void, Never>?
    private var generation: UInt = 0
    private var revision: String?
    private var retainedIDs: Set<UUID> = []
    init(service: any AssistantConversing) { self.service = service }

    @discardableResult func send(question: String, document: TraktorMappingDocument, snapshot: MappingExplanationSnapshot,
        selectedIDs: Set<UUID>, capturedMIDI: SXMJSONMIDI?, destinationDeviceID: UUID?, model: MappingAssistantModel) -> Task<Void, Never> {
        do { try AssistantConversationService.validateQuestion(question) }
        catch { errorMessage = error.localizedDescription; return Task {} }
        if revision != snapshot.revision { invalidate(revision: snapshot.revision) }
        let previous = pendingPlan?.operations ?? []
        currentTask?.cancel(); generation &+= 1
        let requestGeneration = generation
        pendingPlan = nil; errorMessage = nil
        guard document.explanationRevision == snapshot.revision else {
            errorMessage = "The document changed. Refresh the context before sending."
            isWorking = false
            return Task {}
        }
        let file = document.mappingFile
        let targets = Set(previous.compactMap(\.rowID) + previous.flatMap { $0.rowOrder ?? [] })
        let words = Set(question.lowercased().split { !$0.isLetter }.map(String.init))
        let isFollowUp = !words.isDisjoint(with: ["it", "this", "that", "those", "these", "them", "same", "instead", "also", "previous"]) || (words.contains("why") && words.count <= 4) || !previous.isEmpty
        let referencedIDs = isFollowUp ? retainedIDs : []
        let context = context(question: question, snapshot: snapshot, selectedIDs: selectedIDs.union(referencedIDs).union(targets))
        localContext = context
        retainedIDs = Set(context.rows.map(\.id))
        let history = messages.filter { $0.revision == snapshot.revision && ($0.role == "user" || $0.role == "assistant") }.map { AssistantConversationHistory(role: $0.role, text: $0.text) }
        let request = AssistantConversationRequest(question: question, context: context, selectedIDs: selectedIDs.intersection(Set(context.rows.map(\.id))), pendingOperations: previous,
            capturedMIDI: capturedMIDI, destinationDeviceID: destinationDeviceID, availableDevices: snapshot.devices, history: history)
        messages.append(.init(role: "user", text: question, revision: snapshot.revision))
        isWorking = true
        let task = Task { [weak self, weak document, service] in
            do {
                let response = try await service.respond(to: request, model: model)
                try Task.checkCancellation()
                guard let self, let document, self.generation == requestGeneration, self.revision == snapshot.revision else { return }
                guard document.explanationRevision == snapshot.revision, document.mappingFile == file,
                      document.mappingFile.sourceEnvelope == file.sourceEnvelope, document.mappingFile.interchangeMetadata == file.interchangeMetadata else {
                    self.cancel(); self.localContext = nil; self.retainedIDs = []
                    self.invalidate(revision: document.explanationRevision)
                    self.errorMessage = "The document changed while the assistant was responding. Send again with fresh context."
                    return
                }
                try AssistantConversationService.validate(response, request: request)
                let worker = Task.detached {
                    try Task.checkCancellation()
                    return try AssistantEditPlan.prepare(operations: response.operations, file: file, revision: snapshot.revision)
                }
                let plan = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                try Task.checkCancellation()
                guard self.generation == requestGeneration, self.revision == snapshot.revision else { return }
                guard document.explanationRevision == snapshot.revision, document.mappingFile == file, document.mappingFile.sourceEnvelope == file.sourceEnvelope, document.mappingFile.interchangeMetadata == file.interchangeMetadata else {
                    self.cancel(); self.localContext = nil; self.retainedIDs = []
                    self.errorMessage = "The document changed while preparing the review. Send again with fresh context."
                    return
                }
                self.pendingPlan = plan.isEmpty ? nil : plan
                self.retainedIDs.formUnion((response.answer.facts + response.answer.interpretations).flatMap(\.rowIDs))
                let answer: MappingAssistantAnswer
                if !response.operations.isEmpty && plan.isEmpty {
                    answer = MappingAssistantAnswer(facts: response.answer.facts, interpretations: response.answer.interpretations, unknowns: response.answer.unknowns + ["The proposed values already match the mapping. There are no changes to apply."])
                } else { answer = response.answer }
                self.messages.append(.init(role: "assistant", text: Self.text(answer), answer: answer, revision: snapshot.revision))
                self.isWorking = false; self.currentTask = nil
            } catch {
                guard let self, self.generation == requestGeneration else { return }
                self.isWorking = false; self.currentTask = nil; self.pendingPlan = nil
                if !(error is CancellationError) { self.errorMessage = error.localizedDescription }
            }
        }
        currentTask = task
        return task
    }

    func findLocally(question: String, snapshot: MappingExplanationSnapshot, selectedIDs: Set<UUID>) {
        do { try AssistantConversationService.validateQuestion(question) }
        catch { errorMessage = error.localizedDescription; return }
        invalidate(revision: snapshot.revision)
        cancel()
        let context = context(question: question, snapshot: snapshot, selectedIDs: selectedIDs)
        localContext = context; retainedIDs = Set(context.rows.map(\.id))
        let answer = MappingAssistantAnswer(facts: context.rows.map { .init(text: "\($0.deviceName), row \($0.position): \($0.command) · \($0.assignment) · \($0.direction) · \($0.midi)", rowIDs: [$0.id]) }, interpretations: [], unknowns: context.limitations)
        messages.append(.init(role: "user", text: question, revision: snapshot.revision))
        messages.append(.init(role: "assistant", text: Self.text(answer), answer: answer, revision: snapshot.revision))
    }
    func invalidate(revision: String) {
        guard self.revision != revision else { return }
        cancel(); self.revision = revision; localContext = nil; retainedIDs = []
    }
    func cancel() {
        generation &+= 1; currentTask?.cancel(); currentTask = nil
        pendingPlan = nil; isWorking = false; errorMessage = nil
    }
    func discardProposal() { cancel() }
    func clear() { cancel(); messages = []; localContext = nil; retainedIDs = []; revision = nil }
    @discardableResult func apply(document: TraktorMappingDocument, isLocked: Bool, undoManager: UndoManager?) throws -> Bool {
        guard !isWorking, let plan = pendingPlan else { return false }
        do {
            let changed = try plan.apply(document: document, isLocked: isLocked, undoManager: undoManager)
            pendingPlan = nil
            if changed {
                invalidate(revision: document.explanationRevision)
                messages.append(.init(role: "system", text: "Applied the reviewed changes. Previous messages refer to the earlier mapping revision.", revision: document.explanationRevision))
            }
            return changed
        } catch {
            pendingPlan = nil; errorMessage = error.localizedDescription
            throw error
        }
    }
    private func context(question: String, snapshot: MappingExplanationSnapshot, selectedIDs: Set<UUID>) -> ExplanationContext {
        var ids = selectedIDs
        let lower = question.lowercased()
        if ids.isEmpty && ["overview", "organised", "organized", "configuration", "whole mapping", "entire mapping", "summar"].contains(where: lower.contains) {
            // Sample across devices so an overview does not silently describe only the first one.
            let grouped = snapshot.devices.map { device in snapshot.rows.filter { $0.deviceID == device.id } }
            for index in 0..<80 {
                for rows in grouped where index < rows.count && ids.count < 80 { ids.insert(rows[index].id) }
            }
        }
        return MappingExplanationQuery.retrieve(question: question, snapshot: snapshot, selectedIDs: ids)
    }
    private static func text(_ answer: MappingAssistantAnswer) -> String {
        (answer.facts.map(\.text) + answer.interpretations.map(\.text) + answer.unknowns).joined(separator: "\n\n")
    }
}
