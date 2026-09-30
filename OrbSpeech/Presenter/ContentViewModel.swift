import Foundation
import UIKit
import Observation
import Factory

@MainActor
@Observable
final class ContentViewModel {
    
    // MARK: - Internal Properties
    
    private(set) var orbState = OrbState.idle
    private(set) var orbVisualState = OrbVisualState.default
    private(set) var orbVisualTransition: OrbVisualTransition?
    private(set) var isListening = false
    private(set) var statusText = ViewStatus.idle.text
    
    private(set) var onDeviceComponentsState: OnDeviceComponentsState = .idle
    
    var canInteract: Bool {
        onDeviceComponentsState == .success
    }
    
    // MARK: - Private Properties
    
    @ObservationIgnored @Injected(\.microphoneCapturing) private var microphoneCapturing: any MicrophoneCapturing
    @ObservationIgnored @Injected(\.speechRecognizer) private var speechRecognizer: any SpeechRecognizer
    @ObservationIgnored @Injected(\.speechSynthesizer) private var speechSynthesizer: any SpeechSynthesizing
    @ObservationIgnored @Injected(\.commandResolver) private var commandResolver: any CommandResolver
    
    @ObservationIgnored private var lastLevelUpdate = Date.distantPast
    @ObservationIgnored private var lastOrbLevel = 0.0
    @ObservationIgnored private var isListeningLevelUpdatesSuspended = false
    @ObservationIgnored private var shouldResumeListeningAfterForeground = false
    @ObservationIgnored private var listeningSessionState = ListeningSessionState.idle
    
    @ObservationIgnored private lazy var commandFlowCoordinator = {
        CommandFlowCoordinator(initialVisualState: orbVisualState,
                               speaker: self,
                               delegate: self)
    }()
    
    @ObservationIgnored private lazy var voiceCommandCoordinator = {
        VoiceCommandCoordinator(commandResolver: commandResolver,
                                commandFlowCoordinator: commandFlowCoordinator,
                                delegate: self)
    }()
    
    private var isAcceptingSpeechInput: Bool {
        isListening && orbState != .speaking
    }
    
    private var canPublishListeningLevel: Bool {
        isListening && !isListeningLevelUpdatesSuspended
    }
    
    // MARK: - Internal Methods
    
    func prepareOnDeviceComponents() async {
        guard await microphoneCapturing.requestPermission() else {
            setStatus(.microphonePermissionRequired)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }
        
        guard onDeviceComponentsState == .idle else { return }
        
        onDeviceComponentsState = .loading
        appendLog("On-Device prepare: starting")
        
        do {
            try await speechRecognizer.prepare()
            
            onDeviceComponentsState = .success
            try? await commandResolver.prewarm()
            appendLog("On-Device prepare: ready")
        } catch {
            setStatus(.message(error.localizedDescription))
            appendLog("On-Device prepare error: \(error.localizedDescription)")
            onDeviceComponentsState = .failed
        }
    }
    
    func interact() async {
        guard canInteract || isListening else { return }
        if isListening {
            shouldResumeListeningAfterForeground = false
            stopListening()
        } else {
            await startListening()
        }
    }
    
    func pauseListeningForBackground() {
        guard isListening else { return }
        shouldResumeListeningAfterForeground = true
        stopListening(status: .paused,
                      logLine: "listening: paused for background")
    }
    
    func resumeListeningAfterForegroundIfNeeded() async {
        guard shouldResumeListeningAfterForeground else { return }
        shouldResumeListeningAfterForeground = false
        guard canInteract, !isListening else { return }
        
        appendLog("listening: resuming after foreground")
        await startListening()
    }
    
    // MARK: - Private Methods
    
    private func startListening() async {
        shouldResumeListeningAfterForeground = false
        voiceCommandCoordinator.reset()
        
        do {
            try await bindComponents()
            isListening = true
            listeningSessionState = .active
            appendLog("listening: started")
            await speakListeningConfirmation()
        } catch {
            isListening = false
            listeningSessionState = .idle
            setStatus(.message(error.localizedDescription))
            appendLog("listening error: \(error.localizedDescription)")
            orbState = .idle
        }
    }
    
    private func bindComponents() async throws {
        try await speechRecognizer.startStreaming { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard isAcceptingSpeechInput else { return }
                voiceCommandCoordinator.handle(transcription: result)
            }
        }
        
        try microphoneCapturing.start(levelHandler: { [weak self] level in
            guard let self else { return }
            Task { @MainActor in
                guard let orbLevel = self.orbLevelToPublish(from: level) else { return }
                guard self.canPublishListeningLevel else { return }
                self.orbState = .listening(orbLevel)
                self.setStatus(.orb(self.orbState))
            }
        }, bufferHandler: { [weak self] buffer in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard isAcceptingSpeechInput else { return }
                await speechRecognizer.stream(buffer: AudioBufferBox(buffer))
            }
        }, interruptionHandler: { [weak self] interruption in
            Task { @MainActor [weak self] in
                self?.handleMicrophoneInterruption(interruption)
            }
        })
    }
    
    private func stopListening(status nextStatus: ViewStatus? = nil,
                               logLine: String = "listening: stopped") {
        microphoneCapturing.stop()
        voiceCommandCoordinator.reset()
        Task { [speechRecognizer] in
            _ = await speechRecognizer.finishStreaming()
        }
        isListening = false
        listeningSessionState = .idle
        orbState = .idle
        setStatus(nextStatus ?? .orb(orbState))
        appendLog(logLine)
    }
    
    private func handleMicrophoneInterruption(_ interruption: MicrophoneInterruption) {
        switch interruption {
        case .began:
            guard isListening else { return }
            
            voiceCommandCoordinator.reset()
            Task { [speechRecognizer] in
                _ = await speechRecognizer.finishStreaming()
            }
            
            isListening = false
            listeningSessionState = .interrupted
            isListeningLevelUpdatesSuspended = false
            orbState = .idle
            setStatus(.interrupted)
            appendLog("listening: interrupted by audio session")
        case .ended(let shouldResume):
            appendLog("listening: audio session interruption ended, shouldResume=\(shouldResume)")
            guard !isListening, listeningSessionState == .interrupted else { return }
            listeningSessionState = .idle
            orbState = .idle
            setStatus(.ready)
        }
    }
    
    private func appendLog(_ line: String) {
        print("[OrbSpeech] \(line)")
    }
    
    private func orbLevelToPublish(from level: Double) -> Double? {
        let normalizedLevel = level < 0.01 ? 0 : level
        let now = Date.now
        let elapsed = now.timeIntervalSince(lastLevelUpdate)
        let levelDelta = abs(normalizedLevel - lastOrbLevel)
        guard elapsed >= 1.0 / 30.0 || levelDelta >= 0.04 else {
            return nil
        }
        
        lastLevelUpdate = now
        lastOrbLevel = normalizedLevel
        return normalizedLevel
    }
    
    private func speakListeningConfirmation() async {
        isListeningLevelUpdatesSuspended = true
        await speakText(SpeakCommand.listening.text)
        
        guard isListening else {
            isListeningLevelUpdatesSuspended = false
            return
        }
        
        isListeningLevelUpdatesSuspended = false
        orbState = .listening(0)
        setStatus(.orb(orbState))
    }
    
    private func speakText(_ text: String) async {
        orbState = .speaking
        setStatus(.orb(.speaking))
        await speechSynthesizer.speak(text)
    }
    
    private func setStatus(_ status: ViewStatus) {
        statusText = status.text
    }
}

// MARK: - SpeakCommandHandling

extension ContentViewModel: SpeakCommandHandling {
    func speak(_ command: SpeakCommand) async {
        await speakText(command.text)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stop()
    }
}

// MARK: - VoiceCommandCoordinatorDelegate

extension ContentViewModel: VoiceCommandCoordinatorDelegate {
    func voiceCommandCoordinatorDidStartResolving() {
        isListeningLevelUpdatesSuspended = true
        orbState = .thinking
        setStatus(.orb(.thinking))
    }
    
    func voiceCommandCoordinatorDidLog(_ message: String) {
        appendLog(message)
    }
}

// MARK: - CommandFlowCoordinatorDelegate

extension ContentViewModel: CommandFlowCoordinatorDelegate {
    func commandFlowCoordinatorDidStartProcessing() {
        isListeningLevelUpdatesSuspended = true
    }
    
    func commandFlowCoordinatorDidReset() {
        isListeningLevelUpdatesSuspended = false
    }
    
    func commandFlowCoordinatorDidStartActing() {
        orbState = .acting
        setStatus(.orb(.acting))
    }
    
    func commandFlowCoordinatorDidSettle(statusText text: String?) {
        isListeningLevelUpdatesSuspended = false
        let state: OrbState = isListening ? .listening(0) : .idle
        orbState = state
        if let text {
            setStatus(.message(text))
        } else {
            setStatus(.orb(state))
        }
    }
    
    func commandFlowCoordinatorDidUpdateStatus(_ status: CommandOutcomeStatus) {
        setStatus(.commandOutcome(status))
    }
    
    func commandFlowCoordinatorDidUpdateVisualPresentation(state: OrbVisualState,
                                                           transition: OrbVisualTransition?) {
        orbVisualState = state
        orbVisualTransition = transition
    }
    
    func commandFlowCoordinatorDidLog(_ message: String) {
        appendLog(message)
    }
}
