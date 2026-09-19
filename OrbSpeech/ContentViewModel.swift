import Combine
import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var orbState = OrbState.idle
    @Published private(set) var orbVisualState = OrbVisualState.default
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isAppleNativeReady = false
    @Published private(set) var statusText = "idle"
    @Published private(set) var stableTranscript = ""
    @Published private(set) var volatileTranscript = ""
    @Published private(set) var resolvedCommandText = ""
    @Published private(set) var commandOutcomeText = ""

    var canInteract: Bool {
        isAppleNativeReady && !isPreparing
    }

    private let microphone = MicrophoneLevelService()
    private let appleSpeechRecognizer = AppleNativeSpeechRecognizer()
    private let fluidAudioSpeechRecognizer = FluidAudioSpeechRecognizer()
    private let speechSynthesizer = OrbSpeechSynthesizer()
    private let foundationModelsCommandResolver = FoundationModelsCommandResolver()
    private let coreMLCommandResolver = CoreMLModelCommandResolver()
    private var activeSpeechBackend = SpeechRecognizerBackend.appleNative
    private var activeCommandResolver = CommandResolverBackend.foundationModels
    private var commandTask: Task<Void, Never>?
    private var pendingTranscriptTask: Task<Void, Never>?
    private var pendingTranscriptText = ""
    private var lastResolvedTranscript = ""
    private var lastLevelUpdate = Date.distantPast
    private var lastOrbLevel = 0.0
    private var isProcessingCommand = false
    private lazy var commandExecutor = OrbCommandExecutor(initialState: orbVisualState) { [weak self] visualState in
        self?.orbVisualState = visualState
    }

    func prepareAppleNative() async {
        guard !isAppleNativeReady, !isPreparing else { return }

        isPreparing = true
        statusText = "preparing Apple Speech"
        appendLog("prepare: starting Apple Speech")

        do {
            do {
                try await appleSpeechRecognizer.prepare()
                activeSpeechBackend = .appleNative
                statusText = "Apple Speech ready"
                appendLog("prepare: Apple Speech ready")
            } catch {
                appendLog("prepare: Apple Speech unavailable - \(error.localizedDescription)")
                appendLog("prepare: falling back to FluidAudio CoreML ASR")
                try await fluidAudioSpeechRecognizer.prepare()
                activeSpeechBackend = .fluidAudio
                statusText = "CoreML speech ready"
                appendLog("prepare: FluidAudio CoreML ASR ready")
            }

            isAppleNativeReady = true

            do {
                try await foundationModelsCommandResolver.prewarm()
                activeCommandResolver = .foundationModels
                appendLog("prepare: FoundationModels resolver prewarmed")
                statusText = "Apple native ready"
            } catch {
                appendLog("prepare: command resolver unavailable - \(error.localizedDescription)")
                do {
                    try await coreMLCommandResolver.prewarm()
                    activeCommandResolver = .coreML
                    appendLog("prepare: CoreMLModelCommandResolver ready")
                    statusText = "Core ML fallback ready"
                } catch {
                    appendLog("prepare: CoreMLModelCommandResolver unavailable - \(error.localizedDescription)")
                    statusText = "Speech ready, model unavailable"
                }
            }
        } catch {
            statusText = error.localizedDescription
            appendLog("prepare error: \(error.localizedDescription)")
        }

        isPreparing = false
    }

    func interact() async {
        guard canInteract || isListening else { return }
        isListening ? stopListening() : await startListening()
    }

    private func startListening() async {
        let allowed = await microphone.requestPermission()
        guard allowed else {
            statusText = "microphone denied"
            appendLog("microphone error: permission denied")
            orbState = .idle
            return
        }

        do {
            try await startSpeechStreaming { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.handle(transcription: result)
                }
            }

            try microphone.start { [weak self] level in
                guard let self else { return }
                Task { @MainActor in
                    guard let orbLevel = self.orbLevelToPublish(from: level) else { return }
                    self.isListening = true
                    self.statusText = "listening"
                    if !self.isProcessingCommand {
                        self.orbState = .listening(orbLevel)
                    }
                }
            } bufferHandler: { [weak self] buffer in
                Task {
                    await self?.streamSpeech(buffer: AudioBufferBox(buffer))
                }
            }

            isListening = true
            statusText = "listening"
            orbState = .listening(0)
            appendLog("listening: started")
        } catch {
            isListening = false
            statusText = error.localizedDescription
            appendLog("listening error: \(error.localizedDescription)")
            orbState = .idle
        }
    }

    private func stopListening() {
        microphone.stop()
        pendingTranscriptTask?.cancel()
        pendingTranscriptTask = nil
        pendingTranscriptText = ""
        commandTask?.cancel()
        commandTask = nil
        commandExecutor.cancel()
        speechSynthesizer.stop()
        isProcessingCommand = false
        Task { [activeSpeechBackend, appleSpeechRecognizer, fluidAudioSpeechRecognizer] in
            switch activeSpeechBackend {
            case .appleNative:
                _ = await appleSpeechRecognizer.finishStreaming()
            case .fluidAudio:
                _ = try? await fluidAudioSpeechRecognizer.finishStreaming()
            }
        }
        isListening = false
        statusText = "idle"
        orbState = .idle
        appendLog("listening: stopped")
    }

    private func handle(transcription: TranscriptionResult) {
        if !transcription.stableText.isEmpty {
            stableTranscript = transcription.stableText
            volatileTranscript = ""
            appendLog("transcript final: \"\(transcription.stableText)\"")
            scheduleResolveAfterSilenceIfNeeded(transcription.stableText)
        } else {
            volatileTranscript = transcription.volatileText
            scheduleResolveAfterSilenceIfNeeded(transcription.volatileText)
        }
    }

    func executePreviewCommand(action: String, value: String? = nil) async {
        commandTask?.cancel()
        commandTask = nil
        speechSynthesizer.stop()
        isProcessingCommand = true
        orbState = .thinking

        let command = OrbCommand(id: UUID().uuidString,
                                 action: action,
                                 value: value)
        resolvedCommandText = Self.userCommandDescription(command)
        appendLog("preview command: \(Self.shortCommandDescription(command))")
        statusText = "thinking"

        try? await Task.sleep(for: .milliseconds(1500))
        guard !Task.isCancelled else { return }

        orbState = .settling
        statusText = "settling"

        try? await Task.sleep(for: .milliseconds(1500))
        guard !Task.isCancelled else { return }

        orbState = .idle
        isProcessingCommand = false

        await speechSynthesizer.speak("Ok, I'll do what you asked.")
        guard !Task.isCancelled else { return }

        let outcome = await commandExecutor.execute(command)
        commandOutcomeText = Self.userOutcomeDescription(outcome)
        appendLog("preview outcome: \(Self.shortOutcomeDescription(outcome))")
        statusText = outcome.status
    }

    private func resolveAndExecute(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        guard trimmedTranscript != lastResolvedTranscript else { return }

        lastResolvedTranscript = trimmedTranscript
        commandTask?.cancel()
        speechSynthesizer.stop()
        commandExecutor.cancel()
        let backend = activeCommandResolver
        appendLog("resolver: resolving with \(backend.logName) \"\(trimmedTranscript)\"")
        commandTask = Task { [foundationModelsCommandResolver, coreMLCommandResolver] in
            do {
                let command = try await resolveCommand(
                    trimmedTranscript,
                    backend: backend,
                    foundationModelsCommandResolver: foundationModelsCommandResolver,
                    coreMLCommandResolver: coreMLCommandResolver
                )
                guard !Task.isCancelled else { return }

                if command.action == "unknown" {
                    await MainActor.run {
                        isProcessingCommand = false
                        orbState = isListening ? .listening(0) : .idle
                        resolvedCommandText = Self.userCommandDescription(command)
                        commandOutcomeText = ""
                        appendLog("resolver command: \(Self.shortCommandDescription(command))")
                        statusText = "unknown"
                    }
                    return
                }

                await MainActor.run {
                    isProcessingCommand = true
                    orbState = .thinking
                    resolvedCommandText = Self.userCommandDescription(command)
                    appendLog("resolver command: \(Self.shortCommandDescription(command))")
                    statusText = "thinking"
                }

                if command.action == "cancel" {
                    await MainActor.run {
                        cancelCurrentCommandFlow(message: "cancelled")
                    }
                    return
                }

                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    orbState = .settling
                    statusText = "settling"
                }

                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    orbState = isListening ? .listening(0) : .idle
                    isProcessingCommand = false
                }

                await speechSynthesizer.speak("Ok, I'll do what you asked.")
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    statusText = "executing"
                }

                let outcome = await commandExecutor.execute(command)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    if isProcessingCommand {
                        isProcessingCommand = false
                        orbState = isListening ? .listening(0) : .idle
                    }
                    commandOutcomeText = Self.userOutcomeDescription(outcome)
                    appendLog("executor outcome: \(Self.shortOutcomeDescription(outcome))")
                    statusText = outcome.status
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    isProcessingCommand = false
                    orbState = isListening ? .listening(0) : .idle
                    resolvedCommandText = ""
                    commandOutcomeText = error.localizedDescription
                    appendLog("resolver error: \(error.localizedDescription)")
                    statusText = "command failed"
                }
            }
        }
    }

    nonisolated private static func userCommandDescription(_ command: OrbCommand) -> String {
        switch (command.action, command.value?.lowercased()) {
        case ("move", "left"):
            return "Entendi: mover para a esquerda."
        case ("move", "center"), ("move", "middle"):
            return "Entendi: voltar para o centro."
        case ("move", "right"):
            return "Entendi: mover para a direita."
        case ("color", .some(let value)):
            return "Entendi: mudar a cor para \(translatedColor(value))."
        case ("bounce", _):
            return "Entendi: dar um bounce."
        case ("cancel", _):
            return "Entendi: cancelar."
        case ("unknown", _):
            return "Nao encontrei um comando que o orb saiba executar."
        default:
            if let value = command.value {
                return "Entendi: \(command.action) \(value)."
            }
            return "Entendi: \(command.action)."
        }
    }

    nonisolated private static func userOutcomeDescription(_ outcome: CommandOutcome) -> String {
        switch outcome.status {
        case "completed":
            return "Resultado: comando executado."
        case "unsupported":
            if let detail = outcome.detail {
                return "Resultado: nao consegui executar. \(translatedDetail(detail))"
            }
            return "Resultado: nao consegui executar esse comando."
        case "interrupted":
            return "Resultado: comando interrompido."
        default:
            if let detail = outcome.detail {
                return "Resultado: \(translatedDetail(detail))"
            }
            return "Resultado: \(outcome.status)."
        }
    }

    nonisolated private static func shortCommandDescription(_ command: OrbCommand) -> String {
        if let value = command.value {
            return "\(command.action):\(value)"
        }
        return command.action
    }

    nonisolated private static func shortOutcomeDescription(_ outcome: CommandOutcome) -> String {
        if let detail = outcome.detail {
            return "\(outcome.status) - \(detail)"
        }
        return outcome.status
    }

    nonisolated private static func translatedColor(_ value: String) -> String {
        switch value.lowercased() {
        case "blue":
            return "azul"
        case "red":
            return "vermelho"
        case "green":
            return "verde"
        default:
            return value
        }
    }

    nonisolated private static func translatedDetail(_ detail: String) -> String {
        switch detail {
        case "Moved left.":
            return "Movi para a esquerda."
        case "Moved center.":
            return "Voltei para o centro."
        case "Moved right.":
            return "Movi para a direita."
        case "Changed color to blue.":
            return "Mudei a cor para azul."
        case "Changed color to red.":
            return "Mudei a cor para vermelho."
        case "Changed color to green.":
            return "Mudei a cor para verde."
        case "Bounce completed.":
            return "Bounce executado."
        case "Command was interrupted by another command.":
            return "O comando foi interrompido por outro comando."
        default:
            return detail
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
        commandOutcomeText = "Resultado: comando cancelado."
        appendLog("command flow: \(message)")
        statusText = message
    }

    private func resolveCommand(_ transcript: String,
                                backend: CommandResolverBackend,
                                foundationModelsCommandResolver: FoundationModelsCommandResolver,
                                coreMLCommandResolver: CoreMLModelCommandResolver) async throws -> OrbCommand {
        switch backend {
        case .foundationModels:
            do {
                return try await foundationModelsCommandResolver.resolve(transcript)
            } catch {
                appendLog("resolver: FoundationModels failed, retrying with CoreMLModelCommandResolver - \(error.localizedDescription)")
                activeCommandResolver = .coreML
                return try await coreMLCommandResolver.resolve(transcript)
            }
        case .coreML:
            return try await coreMLCommandResolver.resolve(transcript)
        }
    }

    private func startSpeechStreaming(_ onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws {
        switch activeSpeechBackend {
        case .appleNative:
            try await appleSpeechRecognizer.startStreaming(onUpdate: onUpdate)
        case .fluidAudio:
            try await fluidAudioSpeechRecognizer.startStreaming(onUpdate: onUpdate)
        }
    }

    private func streamSpeech(buffer: AudioBufferBox) async {
        switch activeSpeechBackend {
        case .appleNative:
            await appleSpeechRecognizer.stream(buffer: buffer)
        case .fluidAudio:
            await fluidAudioSpeechRecognizer.stream(buffer: buffer)
        }
    }

    private func scheduleResolveAfterSilenceIfNeeded(_ transcript: String) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return }
        guard !Self.isSynthesizedAcknowledgement(trimmedTranscript) else {
            appendLog("transcript ignored synthesized acknowledgement")
            return
        }

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

    nonisolated private static func isSynthesizedAcknowledgement(_ transcript: String) -> Bool {
        let normalized = transcript
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .filter { $0.isLetter || $0.isWhitespace || $0 == "'" }
            .split(separator: " ")
            .joined(separator: " ")

        return normalized == "ok i'll do what you asked"
            || normalized == "okay i'll do what you asked"
            || normalized == "ok i will do what you asked"
            || normalized == "okay i will do what you asked"
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

private enum CommandResolverBackend {
    case foundationModels
    case coreML

    var logName: String {
        switch self {
        case .foundationModels:
            "FoundationModelsCommandResolver"
        case .coreML:
            "CoreMLModelCommandResolver"
        }
    }
}

private enum SpeechRecognizerBackend {
    case appleNative
    case fluidAudio
}
