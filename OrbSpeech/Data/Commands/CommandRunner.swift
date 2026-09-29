import Foundation

@MainActor
final class CommandRunner {
    private enum QueueItem {
        case execute(OrbCommand)
        case refuse(OrbCommand)
    }
    
    private let speaker: any SpeakCommandHandling
    private let commandExecutor: OrbCommandExecutor
    
    private var pendingItems: [QueueItem] = []
    private var runnerID: UUID?
    private var runnerTask: Task<Void, Never>?
    private var cancellationSpeechTask: Task<Void, Never>?
    
    private weak var delegate: (any CommandRunnerDelegate)?
    
    init(initialVisualState: OrbVisualState,
         speaker: any SpeakCommandHandling,
         delegate: (any CommandRunnerDelegate)?) {
        self.speaker = speaker
        self.delegate = delegate
        
        self.commandExecutor = OrbCommandExecutor(initialState: initialVisualState,
                                                  update: { [weak delegate] visualState in
            delegate?.commandRunnerDidUpdateVisualState(visualState)
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
        runnerID = nil
        runnerTask?.cancel()
        runnerTask = nil
        cancellationSpeechTask?.cancel()
        cancellationSpeechTask = nil
        speaker.stopSpeaking()
        commandExecutor.cancel()
        delegate?.commandRunnerDidReset()
    }
    
    private func enqueue(_ item: QueueItem) {
        pendingItems.append(item)
        startRunnerIfNeeded()
    }
    
    private func startRunnerIfNeeded() {
        guard runnerTask == nil else { return }
        let id = UUID()
        runnerID = id
        runnerTask = Task { @MainActor [weak self] in
            await self?.runPendingItems(id: id)
        }
    }
    
    private func runPendingItems(id: UUID) async {
        defer {
            if runnerID == id {
                runnerTask = nil
                runnerID = nil
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
        delegate?.commandRunnerDidStartProcessing()
        
        let speakCommand = SpeakCommand.accepted(command)
        delegate?.commandRunnerDidLog("command speech: \(speakCommand.text)")
        await speaker.speak(speakCommand)
        guard !Task.isCancelled else { return }
        
        delegate?.commandRunnerDidStartActing()
        
        let outcome = await commandExecutor.execute(command)
        guard !Task.isCancelled else { return }
        
        delegate?.commandRunnerDidLog("executor outcome: \(outcome)")
        delegate?.commandRunnerDidUpdateStatus(outcome.status)
    }
    
    private func refuse(_ command: OrbCommand) async {
        delegate?.commandRunnerDidStartProcessing()
        
        delegate?.commandRunnerDidLog("command refusal: \(command)")
        await speaker.speak(.unsupported)
        guard !Task.isCancelled else { return }
        
        delegate?.commandRunnerDidUpdateStatus("unsupported")
    }
    
    private func cancelAll() {
        pendingItems = []
        runnerID = nil
        runnerTask?.cancel()
        runnerTask = nil
        cancellationSpeechTask?.cancel()
        speaker.stopSpeaking()
        commandExecutor.cancel()
        delegate?.commandRunnerDidReset()
        delegate?.commandRunnerDidLog("command flow: cancelled")
        
        cancellationSpeechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            delegate?.commandRunnerDidStartProcessing()
            await speaker.speak(.cancelled)
            
            guard !Task.isCancelled else { return }
            
            settleToListeningOrIdle(statusText: "cancelled")
            cancellationSpeechTask = nil
        }
    }
    
    private func settleToListeningOrIdle(statusText: String? = nil) {
        delegate?.commandRunnerDidSettle(statusText: statusText)
    }
}
