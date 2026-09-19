import Foundation

nonisolated protocol SpeechRecognizer: Sendable {
    func prepare() async throws
    func startStreaming(onUpdate: @escaping @Sendable (TranscriptionResult) -> Void) async throws
    func stream(buffer: AudioBufferBox) async
    func finishStreaming() async -> TranscriptionResult
}
