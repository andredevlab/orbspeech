#if DEBUG
import AVFoundation
import Foundation

final class UITestAudioFixtureMicrophoneService: MicrophoneCapturing, @unchecked Sendable {
    private let audioURL: URL
    private let chunkSize: AVAudioFrameCount = 1_024
    private let lock = NSLock()
    private var streamingTask: Task<Void, Never>?
    private var isRunning = false

    init(audioURL: URL) {
        self.audioURL = audioURL
    }

    func requestPermission() async -> Bool {
        true
    }

    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               interruptionHandler: @escaping @Sendable (MicrophoneInterruption) -> Void) throws {
        let chunks = try loadChunks()

        lock.synchronized {
            streamingTask?.cancel()
            isRunning = true
        }

        streamingTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(300))
            await emit(chunks: chunks,
                       levelHandler: levelHandler,
                       bufferHandler: bufferHandler)
        }
    }

    func stop() {
        lock.synchronized {
            isRunning = false
            streamingTask?.cancel()
            streamingTask = nil
        }
    }

    private func loadChunks() throws -> [AVAudioPCMBuffer] {
        let audioFile = try AVAudioFile(forReading: audioURL,
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false)
        var chunks: [AVAudioPCMBuffer] = []

        while audioFile.framePosition < audioFile.length {
            let count = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize),
                                              audioFile.length - audioFile.framePosition))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                frameCapacity: count) else {
                throw CocoaError(.fileReadCorruptFile)
            }

            try audioFile.read(into: buffer, frameCount: count)
            guard buffer.frameLength > 0 else { break }
            chunks.append(buffer)
        }

        return chunks
    }

    private func emit(chunks: [AVAudioPCMBuffer],
                      levelHandler: @escaping @Sendable (Double) -> Void,
                      bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async {
        for chunk in chunks {
            guard isCaptureRunning else { return }

            bufferHandler(chunk)
            levelHandler(Self.rmsLevel(for: chunk))

            let seconds = Double(chunk.frameLength) / chunk.format.sampleRate
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch {
                return
            }
        }
    }

    private var isCaptureRunning: Bool {
        lock.synchronized { isRunning }
    }

    private static func rmsLevel(for buffer: AVAudioPCMBuffer) -> Double {
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0,
              channelCount > 0,
              let channelData = buffer.floatChannelData else {
            return 0
        }

        var sumSquares = 0.0
        let sampleCount = frameLength * channelCount

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = Double(samples[frame])
                sumSquares += sample * sample
            }
        }

        return sqrt(sumSquares / Double(sampleCount))
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
