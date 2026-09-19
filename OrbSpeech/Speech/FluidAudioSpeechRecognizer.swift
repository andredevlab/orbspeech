@preconcurrency import AVFoundation
import FluidAudio
import Foundation

actor FluidAudioSpeechRecognizer {
    private var models: AsrModels?
    private var streamingManager: SlidingWindowAsrManager?
    private var updateTask: Task<Void, Never>?
    private var isPrepared = false

    func prepare() async throws {
        guard !isPrepared else { return }

        print("[OrbSpeech] FluidAudio: downloading/loading Parakeet TDT-CTC 110M CoreML")
        let models = try await AsrModels.downloadAndLoad(version: .tdtCtc110m) { progress in
            print("[OrbSpeech] FluidAudio: progress phase=\(progress.phase) fraction=\(String(format: "%.3f", progress.fractionCompleted))")
        }

        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)

        self.models = models
        isPrepared = true
        print("[OrbSpeech] FluidAudio: model ready")
    }

    func startStreaming(onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws {
        try await prepare()
        guard let models else {
            throw FluidAudioSpeechRecognizerError.notReady
        }

        updateTask?.cancel()
        if let streamingManager {
            await streamingManager.cancel()
        }

        let config = SlidingWindowAsrConfig(
            chunkSeconds: 5.0,
            hypothesisChunkSeconds: 1.0,
            leftContextSeconds: 2.0,
            rightContextSeconds: 2.0,
            minContextForConfirmation: 6.0,
            confirmationThreshold: 0.80
        )
        let stream = SlidingWindowAsrManager(config: config)
        try await stream.loadModels(models)
        try await stream.startStreaming(source: .system)
        print("[OrbSpeech] FluidAudio: streaming from app-provided audio buffers")
        streamingManager = stream

        updateTask = Task {
            for await update in await stream.transcriptionUpdates {
                let text = update.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = update.isConfirmed
                    ? TranscriptionResult(stableText: text, volatileText: "")
                    : TranscriptionResult(stableText: "", volatileText: text)
                onUpdate(result)
            }
        }
    }

    func stream(buffer: AudioBufferBox) async {
        guard let streamingManager else { return }
        await streamingManager.streamAudio(buffer.buffer)
    }

    func finishStreaming() async throws -> TranscriptionResult {
        guard let streamingManager else {
            return TranscriptionResult(stableText: "", volatileText: "")
        }

        let text = try await streamingManager.finish().trimmingCharacters(in: .whitespacesAndNewlines)
        updateTask?.cancel()
        updateTask = nil
        self.streamingManager = nil
        return TranscriptionResult(stableText: text, volatileText: "")
    }
}

enum FluidAudioSpeechRecognizerError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady:
            "Modelo CoreML local ainda nao esta preparado."
        }
    }
}
