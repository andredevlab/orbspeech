@preconcurrency import AVFoundation
import Foundation
import Speech

actor AppleNativeSpeechRecognizer: SpeechRecognizer {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isPrepared = false
    private var latestText = ""

    func prepare() async throws {
        guard !isPrepared else { return }

        let authorization = await Self.requestSpeechAuthorization()
        guard authorization == .authorized else {
            throw AppleNativeSpeechRecognizerError.authorizationDenied
        }

        let locale = Locale(identifier: "en_US")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw AppleNativeSpeechRecognizerError.recognizerUnavailable
        }

        self.recognizer = recognizer
        isPrepared = true
    }

    func startStreaming(onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws {
        try await prepare()
        guard let recognizer else {
            throw AppleNativeSpeechRecognizerError.recognizerUnavailable
        }

        recognitionTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        latestText = ""
        self.request = request
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }

            let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                await self?.setLatestText(text)
            }

            let transcription = result.isFinal
                ? TranscriptionResult(stableText: text, volatileText: "")
                : TranscriptionResult(stableText: "", volatileText: text)
            onUpdate(transcription)
        }
    }

    func stream(buffer: AudioBufferBox) {
        request?.append(buffer.buffer)
    }

    func finishStreaming() async -> TranscriptionResult {
        request?.endAudio()
        recognitionTask?.finish()
        let text = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        request = nil
        recognitionTask = nil
        return TranscriptionResult(stableText: text, volatileText: "")
    }

    private func setLatestText(_ text: String) {
        latestText = text
    }

    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

enum AppleNativeSpeechRecognizerError: LocalizedError {
    case authorizationDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Permissao de reconhecimento de fala negada."
        case .recognizerUnavailable:
            "Reconhecimento de fala Apple indisponivel neste dispositivo ou idioma."
        }
    }
}
