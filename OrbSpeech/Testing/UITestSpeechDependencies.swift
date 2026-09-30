#if DEBUG
import Foundation

final class UITestSpeechRecognizer: SpeechRecognizer, @unchecked Sendable {
    private let transcript: String
    private let lock = NSLock()
    private var onUpdate: (@Sendable (TranscriptionResult) -> Void)?
    private var didEmitTranscript = false
    private var scheduledTranscriptTask: Task<Void, Never>?

    init(transcript: String) {
        self.transcript = transcript
    }

    func prepare() async throws {
    }

    func startStreaming(onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws {
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.emitTranscriptIfNeeded()
        }

        lock.synchronized {
            scheduledTranscriptTask?.cancel()
            self.onUpdate = onUpdate
            didEmitTranscript = false
            scheduledTranscriptTask = task
        }
    }

    func stream(buffer: AudioBufferBox) async {
    }

    func finishStreaming() async -> TranscriptionResult {
        lock.synchronized {
            scheduledTranscriptTask?.cancel()
            scheduledTranscriptTask = nil
        }

        return TranscriptionResult(stableText: transcript, volatileText: "")
    }

    private func emitTranscriptIfNeeded() {
        let callback = lock.synchronized {
            guard !didEmitTranscript else { return nil as (@Sendable (TranscriptionResult) -> Void)? }
            didEmitTranscript = true
            scheduledTranscriptTask?.cancel()
            scheduledTranscriptTask = nil
            return onUpdate
        }

        callback?(TranscriptionResult(stableText: transcript, volatileText: ""))
    }
}

@MainActor
final class UITestSpeechSynthesizer: SpeechSynthesizing {
    func speak(_ text: String) async {
    }

    func stop() {
    }
}

actor UITestCommandResolver: CommandResolver {
    func prewarm() async throws {
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        if transcript.localizedCaseInsensitiveContains("move left") {
            return OrbCommand(action: .move, value: OrbMoveTarget.left.rawValue)
        }

        return OrbCommand(action: .unknown)
    }
}

private extension NSLock {
    nonisolated func synchronized<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
#endif
