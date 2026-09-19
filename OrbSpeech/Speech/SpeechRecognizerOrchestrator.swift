import Foundation

actor SpeechRecognizerOrchestrator: SpeechRecognizer {
    private enum ActiveRecognizer {
        case appleNative
        case fluidAudio
    }

    private let appleNativeSpeechRecognizer: AppleNativeSpeechRecognizer
    private let fluidAudioSpeechRecognizer: FluidAudioSpeechRecognizer
    private var activeRecognizer: ActiveRecognizer?

    init() {
        self.appleNativeSpeechRecognizer = AppleNativeSpeechRecognizer()
        self.fluidAudioSpeechRecognizer = FluidAudioSpeechRecognizer()
    }

    init(appleNativeSpeechRecognizer: AppleNativeSpeechRecognizer,
         fluidAudioSpeechRecognizer: FluidAudioSpeechRecognizer) {
        self.appleNativeSpeechRecognizer = appleNativeSpeechRecognizer
        self.fluidAudioSpeechRecognizer = fluidAudioSpeechRecognizer
    }

    func prepare() async throws {
        do {
            try await appleNativeSpeechRecognizer.prepare()
            activeRecognizer = .appleNative
            print("[OrbSpeech] speech orchestrator: Apple Speech ready")
        } catch {
            print("[OrbSpeech] speech orchestrator: Apple Speech unavailable, trying FluidAudio - \(error.localizedDescription)")
            try await fluidAudioSpeechRecognizer.prepare()
            activeRecognizer = .fluidAudio
            print("[OrbSpeech] speech orchestrator: FluidAudio ready")
        }
    }

    func startStreaming(onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws {
        if activeRecognizer == nil {
            try await prepare()
        }

        switch activeRecognizer {
        case .appleNative:
            try await appleNativeSpeechRecognizer.startStreaming(onUpdate: onUpdate)
        case .fluidAudio:
            try await fluidAudioSpeechRecognizer.startStreaming(onUpdate: onUpdate)
        case nil:
            throw SpeechRecognizerOrchestratorError.noActiveRecognizer
        }
    }

    func stream(buffer: AudioBufferBox) async {
        switch activeRecognizer {
        case .appleNative:
            await appleNativeSpeechRecognizer.stream(buffer: buffer)
        case .fluidAudio:
            await fluidAudioSpeechRecognizer.stream(buffer: buffer)
        case nil:
            return
        }
    }

    func finishStreaming() async -> TranscriptionResult {
        switch activeRecognizer {
        case .appleNative:
            return await appleNativeSpeechRecognizer.finishStreaming()
        case .fluidAudio:
            return await fluidAudioSpeechRecognizer.finishStreaming()
        case nil:
            return TranscriptionResult(stableText: "", volatileText: "")
        }
    }
}

enum SpeechRecognizerOrchestratorError: LocalizedError {
    case noActiveRecognizer

    var errorDescription: String? {
        switch self {
        case .noActiveRecognizer:
            "No speech recognizer is active."
        }
    }
}
