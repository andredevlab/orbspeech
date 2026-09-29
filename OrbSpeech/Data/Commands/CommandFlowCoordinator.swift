import Foundation

@MainActor
final class CommandFlowCoordinator {
    private enum QueueItem {
        case execute(OrbCommand)
        case refuse(OrbCommand)
    }
    
    private let speaker: any SpeakCommandHandling
    private let commandExecutor: OrbCommandExecutor
    
    private var pendingItems: [QueueItem] = []
    private var flowID: UUID?
    private var flowTask: Task<Void, Never>?
    private var cancellationSpeechTask: Task<Void, Never>?
    
    private weak var delegate: (any CommandFlowCoordinatorDelegate)?
    
    init(initialVisualState: OrbVisualState,
         speaker: any SpeakCommandHandling,
         delegate: (any CommandFlowCoordinatorDelegate)?) {
        self.speaker = speaker
        self.delegate = delegate
        
        self.commandExecutor = OrbCommandExecutor(initialState: initialVisualState,
                                                  update: { [weak delegate] visualState in
            delegate?.commandFlowCoordinatorDidUpdateVisualState(visualState)
        })
    }
    
    func submit(_ command: OrbCommand) {
        switch command.action {
        case "cancel":
            cancelAll()
        case "unknown":
            enqueue(.refuse(command))
        case "move", "color", "bounce":
            enqueue(.execute(command))
        default:
            enqueue(.refuse(command))
        }
    }
    
    func reset() {
        pendingItems = []
        flowID = nil
        flowTask?.cancel()
        flowTask = nil
        cancellationSpeechTask?.cancel()
        cancellationSpeechTask = nil
        speaker.stopSpeaking()
        commandExecutor.cancel()
        delegate?.commandFlowCoordinatorDidReset()
    }
    
    private func enqueue(_ item: QueueItem) {
        pendingItems.append(item)
        startFlowIfNeeded()
    }
    
    private func startFlowIfNeeded() {
        guard flowTask == nil else { return }
        let id = UUID()
        flowID = id
        flowTask = Task { @MainActor [weak self] in
            await self?.runPendingItems(id: id)
        }
    }
    
    private func runPendingItems(id: UUID) async {
        defer {
            if flowID == id {
                flowTask = nil
                flowID = nil
                if !Task.isCancelled {
                    settleToListeningOrIdle()
                }
            }
        }
        
        while !Task.isCancelled, !pendingItems.isEmpty {
            let item = pendingItems.removeFirst()
            switch item {
            case .execute(let command):
                await execute(command)
            case .refuse(let command):
                await refuse(command)
            }
        }
    }
    
    private func execute(_ command: OrbCommand) async {
        delegate?.commandFlowCoordinatorDidStartProcessing()
        
        let speakCommand = SpeakCommand.accepted(command)
        delegate?.commandFlowCoordinatorDidLog("command speech: \(speakCommand.text)")
        await speaker.speak(speakCommand)
        guard !Task.isCancelled else { return }
        
        delegate?.commandFlowCoordinatorDidStartActing()
        
        let outcome = await commandExecutor.execute(command)
        guard !Task.isCancelled else { return }
        
        delegate?.commandFlowCoordinatorDidLog("executor outcome: \(outcome)")
        delegate?.commandFlowCoordinatorDidUpdateStatus(outcome.status)
    }
    
    private func refuse(_ command: OrbCommand) async {
        delegate?.commandFlowCoordinatorDidStartProcessing()
        
        delegate?.commandFlowCoordinatorDidLog("command refusal: \(command)")
        await speaker.speak(.unsupported)
        guard !Task.isCancelled else { return }
        
        delegate?.commandFlowCoordinatorDidUpdateStatus("unsupported")
    }
    
    private func cancelAll() {
        pendingItems = []
        flowID = nil
        flowTask?.cancel()
        flowTask = nil
        cancellationSpeechTask?.cancel()
        speaker.stopSpeaking()
        commandExecutor.cancel()
        delegate?.commandFlowCoordinatorDidReset()
        delegate?.commandFlowCoordinatorDidLog("command flow: cancelled")
        
        cancellationSpeechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            delegate?.commandFlowCoordinatorDidStartProcessing()
            await speaker.speak(.cancelled)
            
            guard !Task.isCancelled else { return }
            
            settleToListeningOrIdle(statusText: "cancelled")
            cancellationSpeechTask = nil
        }
    }
    
    private func settleToListeningOrIdle(statusText: String? = nil) {
        delegate?.commandFlowCoordinatorDidSettle(statusText: statusText)
    }
}
