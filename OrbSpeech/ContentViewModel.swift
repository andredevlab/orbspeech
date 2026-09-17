import Combine
import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var orbState = OrbState.idle
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isAppleNativeReady = false
    @Published private(set) var statusText = "idle"
    @Published private(set) var stableTranscript = ""
    @Published private(set) var volatileTranscript = ""

    var canInteract: Bool {
        isAppleNativeReady && !isPreparing
    }

    private let microphone = MicrophoneLevelService()
    private let recognizer = AppleNativeSpeechRecognizer()

    func prepareAppleNative() async {
        guard !isAppleNativeReady, !isPreparing else { return }

        isPreparing = true
        statusText = "preparing Apple native"

        do {
            try await recognizer.prepare()
            isAppleNativeReady = true
            statusText = "Apple native ready"
        } catch {
            statusText = error.localizedDescription
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
            orbState = .idle
            return
        }

        do {
            try await recognizer.startStreaming { [weak self] result in
                Task { @MainActor in
                    self?.handle(transcription: result)
                }
            }

            try microphone.start { [weak self] level in
                guard let self else { return }
                Task { @MainActor in
                    self.isListening = true
                    self.statusText = "listening"
                    self.orbState = .listening(level)
                }
            } bufferHandler: { [recognizer] buffer in
                Task {
                    await recognizer.stream(buffer: AudioBufferBox(buffer))
                }
            }

            isListening = true
            statusText = "listening"
            orbState = .listening(0)
        } catch {
            isListening = false
            statusText = error.localizedDescription
            orbState = .idle
        }
    }

    private func stopListening() {
        microphone.stop()
        Task { [recognizer] in
            _ = await recognizer.finishStreaming()
        }
        isListening = false
        statusText = "idle"
        orbState = .idle
    }

    private func handle(transcription: TranscriptionResult) {
        if !transcription.stableText.isEmpty {
            stableTranscript = transcription.stableText
            volatileTranscript = ""
        } else {
            volatileTranscript = transcription.volatileText
        }
    }
}
