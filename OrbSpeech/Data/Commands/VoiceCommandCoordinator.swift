import Foundation

@MainActor
final class VoiceCommandCoordinator {
    private let commandResolver: any CommandResolver
    private let commandFlowCoordinator: CommandFlowCoordinator
    
    private let transcriptSegmenter = TranscriptSegmenter()
    private var resolveTasks: [UUID: Task<Void, Never>] = [:]
    private var pendingTranscriptTask: Task<Void, Never>?
    private var pendingTranscriptText = ""
    private var lastResolvedTranscript = ""
    
    private weak var delegate: (any VoiceCommandCoordinatorDelegate)?
    
    init(commandResolver: any CommandResolver,
         commandFlowCoordinator: CommandFlowCoordinator,
         delegate: (any VoiceCommandCoordinatorDelegate)?) {
        self.commandResolver = commandResolver
        self.commandFlowCoordinator = commandFlowCoordinator
        self.delegate = delegate
    }
    
    func handle(transcription: TranscriptionResult) {
        let segmentedResult = transcriptSegmenter.segment(transcription)
        
        if !segmentedResult.stableText.isEmpty {
            delegate?.voiceCommandCoordinatorDidLog("transcript final: \"\(segmentedResult.stableText)\"")
            debounceTranscriptResolution(segmentedResult.stableText)
        } else {
            debounceTranscriptResolution(segmentedResult.volatileText)
        }
    }
    
    func reset() {
        pendingTranscriptTask?.cancel()
        pendingTranscriptTask = nil
        pendingTranscriptText = ""
        transcriptSegmenter.reset()
        lastResolvedTranscript = ""
        cancelResolveTasks()
        commandFlowCoordinator.reset()
    }
    
    private func debounceTranscriptResolution(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        
        pendingTranscriptTask?.cancel()
        if pendingTranscriptText != trimmedTranscript {
            delegate?.voiceCommandCoordinatorDidLog("resolver: waiting for 1s silence after \(transcript)")
        }
        pendingTranscriptText = trimmedTranscript
        pendingTranscriptTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.pendingTranscriptText = ""
                self?.resolveAndSubmit(trimmedTranscript)
            }
        }
    }
    
    private func resolveAndSubmit(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        guard trimmedTranscript != lastResolvedTranscript else { return }
        
        lastResolvedTranscript = trimmedTranscript
        delegate?.voiceCommandCoordinatorDidStartResolving()
        delegate?.voiceCommandCoordinatorDidLog("resolver: resolving \"\(trimmedTranscript)\"")
        transcriptSegmenter.commit(trimmedTranscript)
        
        let taskID = UUID()
        let task = Task { @MainActor [weak self, commandResolver] in
            guard let self else { return }
            defer { self.resolveTasks[taskID] = nil }
            
            do {
                let command = try await commandResolver.resolve(trimmedTranscript)
                guard !Task.isCancelled else { return }
                
                self.delegate?.voiceCommandCoordinatorDidLog("resolver command: \(command)")
                if command.action == .cancel {
                    self.cancelResolveTasks(except: taskID)
                }
                self.commandFlowCoordinator.submit(command)
            } catch {
                guard !Task.isCancelled else { return }
                self.delegate?.voiceCommandCoordinatorDidLog("resolver error: \(error.localizedDescription)")
                self.commandFlowCoordinator.submit(OrbCommand(action: .unknown))
            }
        }
        resolveTasks[taskID] = task
    }
    
    private func cancelResolveTasks(except activeTaskID: UUID? = nil) {
        let taskIDs = resolveTasks.keys.filter { $0 != activeTaskID }
        for taskID in taskIDs {
            resolveTasks[taskID]?.cancel()
            resolveTasks[taskID] = nil
        }
    }
}
