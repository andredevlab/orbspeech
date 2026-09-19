import Foundation
import UIKit
import Observation

enum State {
    case idle, loading, success, failed
}
@MainActor
@Observable
final class ContentViewModel {
    private(set) var orbState = OrbState.idle
    private(set) var orbVisualState = OrbVisualState.default
    private(set) var isListening = false
    private(set) var statusText = "idle"
    
    private(set) var onDeviceComponentsState: State = .idle
    private(set) var microphoneCapturingState: State = .idle
    
    var canInteract: Bool {
        onDeviceComponentsState == .success
    }
    
    @ObservationIgnored private let microphoneCapturing: any MicrophoneCapturing
    @ObservationIgnored private let speechRecognizer: any SpeechRecognizer
    @ObservationIgnored private let speechSynthesizer: any SpeechSynthesizing
    @ObservationIgnored private let commandResolver: any CommandResolver
    
    @ObservationIgnored private var commandTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTranscriptTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTranscriptText = ""
    @ObservationIgnored private var lastResolvedTranscript = ""
    @ObservationIgnored private var lastLevelUpdate = Date.distantPast
    @ObservationIgnored private var lastOrbLevel = 0.0
    @ObservationIgnored private var isProcessingCommand = false
    @ObservationIgnored private lazy var commandExecutor = OrbCommandExecutor(initialState: orbVisualState) { [weak self] visualState in
        self?.orbVisualState = visualState
    }
    
    init(microphoneCapturing: any MicrophoneCapturing,
         speechRecognizer: any SpeechRecognizer,
         speechSynthesizer: any SpeechSynthesizing,
         commandResolver: any CommandResolver) {
        self.microphoneCapturing = microphoneCapturing
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
        self.commandResolver = commandResolver
    }
    
    func prepareOnDeviceComponents() async {
        guard await microphoneCapturing.requestPermission() else {
            statusText = "You should allow microphone permission."
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
            statusText = error.localizedDescription
            appendLog("On-Device prepare error: \(error.localizedDescription)")
            onDeviceComponentsState = .failed
        }
    }
    
    func interact() async {
        guard canInteract || isListening else { return }
        isListening ? stopListening() : await startListening()
    }
    
    private func startListening() async {
        do {
            try await speechRecognizer.startStreaming { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard orbState != .speaking else { return }
                    self.handle(transcription: result)
                }
            }
            
            try microphoneCapturing.start { [weak self] level in
                guard let self else { return }
                Task { @MainActor in
                    guard let orbLevel = self.orbLevelToPublish(from: level) else { return }
                    self.isListening = true
                    if !self.isProcessingCommand {
                        self.orbState = .listening(orbLevel)
                    }
                    self.statusText = self.orbState.description
                }
            } bufferHandler: { [weak self] buffer in
                Task {
                    await self?.speechRecognizer.stream(buffer: AudioBufferBox(buffer))
                }
            }
            
            isListening = true
            appendLog("listening: started")
        } catch {
            isListening = false
            statusText = error.localizedDescription
            appendLog("listening error: \(error.localizedDescription)")
            orbState = .idle
        }
    }
    
    private func stopListening() {
        microphoneCapturing.stop()
        pendingTranscriptTask?.cancel()
        pendingTranscriptTask = nil
        pendingTranscriptText = ""
        commandTask?.cancel()
        commandTask = nil
        commandExecutor.cancel()
        speechSynthesizer.stop()
        isProcessingCommand = false
        Task { [speechRecognizer] in
            _ = await speechRecognizer.finishStreaming()
        }
        isListening = false
        orbState = .idle
        statusText = orbState.description
        appendLog("listening: stopped")
    }
    
    private func handle(transcription: TranscriptionResult) {
        if !transcription.stableText.isEmpty {
            appendLog("transcript final: \"\(transcription.stableText)\"")
            scheduleResolveAfterSilenceIfNeeded(transcription.stableText)
        } else {
            scheduleResolveAfterSilenceIfNeeded(transcription.volatileText)
        }
    }
    
    private func resolveAndExecute(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        guard trimmedTranscript != lastResolvedTranscript else { return }
        
        lastResolvedTranscript = trimmedTranscript
        commandTask?.cancel()
        speechSynthesizer.stop()
        commandExecutor.cancel()
        isProcessingCommand = true
        orbState = .thinking
        statusText = orbState.description
        appendLog("resolver: resolving \"\(trimmedTranscript)\"")
        commandTask = Task { [commandResolver] in
            do {
                let command = try await commandResolver.resolve(trimmedTranscript)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    appendLog("resolver command: \(command)")
                    orbState = .settling
                    statusText = orbState.description
                }
                
                if command.action == "cancel" {
                    await MainActor.run {
                        cancelCurrentCommandFlow(message: "cancelled")
                    }
                    return
                }
                
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
                
                if command.action == "unknown" {
                    await MainActor.run {
                        isProcessingCommand = false
                        orbState = isListening ? .listening(0) : .idle
                        statusText = "unknown"
                    }
                    return
                }
                
                await MainActor.run {
                    orbState = .speaking
                    isProcessingCommand = true
                    statusText = orbState.description
                }
                
                await speechSynthesizer.speak("Ok, I'll do what you asked.")
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    orbState = .acting
                    isProcessingCommand = true
                    statusText = orbState.description
                }
                
                let outcome = await commandExecutor.execute(command)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    isProcessingCommand = false
                    orbState = isListening ? .listening(0) : .idle
                    appendLog("executor outcome: \(outcome)")
                    statusText = outcome.status
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isProcessingCommand = false
                    orbState = isListening ? .listening(0) : .idle
                    appendLog("resolver error: \(error.localizedDescription)")
                    statusText = "command failed"
                }
            }
        }
    }
    
    private func appendLog(_ line: String) {
        print("[OrbSpeech] \(line)")
    }
    
    private func cancelCurrentCommandFlow(message: String) {
        speechSynthesizer.stop()
        commandExecutor.cancel()
        isProcessingCommand = false
        orbState = isListening ? .listening(0) : .idle
        
        appendLog("command flow: \(message)")
        statusText = message
    }
    
    private func scheduleResolveAfterSilenceIfNeeded(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        
        pendingTranscriptTask?.cancel()
        if pendingTranscriptText != trimmedTranscript {
            appendLog("resolver: waiting for 1s silence")
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
                self?.resolveAndExecute(trimmedTranscript)
            }
        }
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
}
