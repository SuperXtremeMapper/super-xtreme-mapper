import Foundation
import Combine

@MainActor
final class MappingAssistantCoordinator: ObservableObject {
    @Published private(set) var answer: MappingAssistantAnswer?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    private let service: any MappingAnswering
    private var currentTask: Task<Void, Never>?
    private var generation: UInt = 0
    private var revision: String?

    init(service: any MappingAnswering) {
        self.service = service
    }

    @discardableResult
    func ask(
        question: String,
        contextJSON: Data,
        allowedRowIDs: Set<UUID>,
        revision: String,
        model: MappingAssistantModel
    ) -> Task<Void, Never> {
        currentTask?.cancel()
        generation &+= 1
        let requestGeneration = generation
        self.revision = revision
        answer = nil
        errorMessage = nil
        isWorking = true

        let task = Task { [weak self, service] in
            do {
                let result = try await service.answer(
                    question: question,
                    contextJSON: contextJSON,
                    allowedRowIDs: allowedRowIDs,
                    model: model
                )
                guard let self,
                      self.generation == requestGeneration,
                      self.revision == revision else { return }
                self.answer = result
                self.errorMessage = nil
                self.isWorking = false
                self.currentTask = nil
            } catch is CancellationError {
                guard let self, self.generation == requestGeneration else { return }
                self.isWorking = false
                self.currentTask = nil
            } catch {
                guard let self,
                      self.generation == requestGeneration,
                      self.revision == revision else { return }
                self.answer = nil
                self.errorMessage = error.localizedDescription
                self.isWorking = false
                self.currentTask = nil
            }
        }
        currentTask = task
        return task
    }

    func cancel() {
        generation &+= 1
        currentTask?.cancel()
        currentTask = nil
        answer = nil
        errorMessage = nil
        isWorking = false
    }

    func invalidate(revision: String) {
        guard self.revision != revision else { return }
        generation &+= 1
        currentTask?.cancel()
        currentTask = nil
        self.revision = revision
        answer = nil
        errorMessage = nil
        isWorking = false
    }
}
