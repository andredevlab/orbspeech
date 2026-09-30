@preconcurrency import AVFoundation
import Foundation
import Testing
@testable import OrbSpeech

@Suite("FluidAudio recognizer integration")
struct FluidAudioRecognizerIntegrationTests {
    @Test("Transcribes the bundled move_left audio fixture")
    func transcribesMoveLeftFixture() async throws {
        let chunks = try Self.loadAudioChunks(from: try Self.audioFixtureURL())
        let recognizer = FluidAudioSpeechRecognizer()

        // This is intentionally an integration test: startStreaming() calls prepare(),
        // which may download/cache FluidAudio model assets on the first run.
        try await recognizer.startStreaming { _ in }

        for chunk in chunks {
            await recognizer.stream(buffer: AudioBufferBox(chunk))
        }

        let transcriptResult = await recognizer.finishStreaming()
        let volatileText = await transcriptResult.volatileText
        let stableText = await transcriptResult.stableText

        let normalizedText = [stableText, volatileText]
            .joined(separator: " ")
            .normalizedText()

        #expect(
            normalizedText.contains("move left") || normalizedText.contains("move to the left"),
            "Unexpected FluidAudio transcript: '\(normalizedText)'"
        )
    }

    private static func audioFixtureURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "move_left",
                                        withExtension: "wav") else {
            throw FluidAudioRecognizerIntegrationTestError.fixtureMissing(bundlePath: Bundle.main.bundleURL.path)
        }

        return url
    }

    private static func loadAudioChunks(from url: URL,
                                        framesPerChunk: AVAudioFrameCount = 1_024) throws -> [AVAudioPCMBuffer] {
        let audioFile = try AVAudioFile(forReading: url,
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false)
        var chunks: [AVAudioPCMBuffer] = []

        while audioFile.framePosition < audioFile.length {
            let frameCount = AVAudioFrameCount(min(AVAudioFramePosition(framesPerChunk),
                                                  audioFile.length - audioFile.framePosition))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                frameCapacity: frameCount) else {
                throw FluidAudioRecognizerIntegrationTestError.couldNotCreateBuffer(url: url)
            }

            try audioFile.read(into: buffer, frameCount: frameCount)
            guard buffer.frameLength > 0 else { break }
            chunks.append(buffer)
        }

        guard !chunks.isEmpty else {
            throw FluidAudioRecognizerIntegrationTestError.emptyFixture(url: url)
        }

        return chunks
    }
}

private enum FluidAudioRecognizerIntegrationTestError: LocalizedError, CustomStringConvertible {
    case fixtureMissing(bundlePath: String)
    case couldNotCreateBuffer(url: URL)
    case emptyFixture(url: URL)

    var errorDescription: String? {
        switch self {
        case .fixtureMissing(let bundlePath):
            return "Could not find move_left.wav in the host app bundle at '\(bundlePath)'."
        case .couldNotCreateBuffer(let url):
            return "Could not create an AVAudioPCMBuffer while reading '\(url.path)'."
        case .emptyFixture(let url):
            return "Audio fixture '\(url.path)' did not produce any buffers."
        }
    }

    var description: String {
        errorDescription ?? String(describing: self)
    }
}
