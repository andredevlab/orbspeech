import AVFoundation
import Foundation
@testable import OrbSpeech

final class FileMicrophoneService: MicrophoneCapturing, @unchecked Sendable {
    private let commandName: String
    private let bundle: Bundle
    private let startsAutomatically: Bool
    private let playbackDelay: Duration?
    private let chunkSize: AVAudioFrameCount = 1_024
    private let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: 16_000,
                                             channels: 1,
                                             interleaved: false)!
    
    private let lock = NSLock()
    private var isRunning = false
    private var playbackRequested = false
    private var playbackStartContinuation: CheckedContinuation<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    
    let events: AsyncStream<FileMicrophoneServiceEvent>
    private let eventContinuation: AsyncStream<FileMicrophoneServiceEvent>.Continuation
    
    init(commandName: String,
         bundle: Bundle,
         startsAutomatically: Bool = true,
         playbackDelay: Duration? = nil) {
        self.commandName = commandName
        self.bundle = bundle
        self.startsAutomatically = startsAutomatically
        self.playbackDelay = playbackDelay
        
        let stream = AsyncStream<FileMicrophoneServiceEvent>.makeStream(bufferingPolicy: .unbounded)
        events = stream.stream
        eventContinuation = stream.continuation
    }
    
    func requestPermission() async -> Bool {
        true
    }
    
    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               interruptionHandler: @escaping @Sendable (MicrophoneInterruption) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        
        guard let audioURL = bundle.audioFixtureURL(for: commandName) else {
            throw FileMicrophoneServiceError.audioFileMissing("\(commandName).wav")
        }
        
        let chunks = try loadChunks(from: audioURL)
        
        lock.synchronized {
            streamingTask?.cancel()
            isRunning = true
            playbackRequested = startsAutomatically
            playbackStartContinuation = nil
        }
        
        streamingTask = Task { [weak self] in
            guard let self else { return }
            await waitForPlaybackStartIfNeeded()
            if let playbackDelay {
                try? await Task.sleep(for: playbackDelay)
            }
            await emit(chunks: chunks,
                       levelHandler: levelHandler,
                       bufferHandler: bufferHandler)
        }
    }
    
    func stop() {
        let continuation = lock.synchronized {
            isRunning = false
            playbackRequested = true
            let continuation = playbackStartContinuation
            playbackStartContinuation = nil
            streamingTask?.cancel()
            streamingTask = nil
            return continuation
        }
        continuation?.resume()
        eventContinuation.finish()
    }
    
    func beginPlayback() {
        let continuation = lock.synchronized {
            playbackRequested = true
            let continuation = playbackStartContinuation
            playbackStartContinuation = nil
            return continuation
        }
        continuation?.resume()
    }
    
    private func loadChunks(from audioURL: URL) throws -> [AVAudioPCMBuffer] {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL,
                                        commonFormat: .pcmFormatFloat32,
                                        interleaved: false)
        } catch {
            throw FileMicrophoneServiceError.audioFileUnreadable(audioURL.lastPathComponent, error)
        }
        
        guard audioFile.length > 0 else {
            throw FileMicrophoneServiceError.prepareFailed("Empty audio file: \(audioURL.lastPathComponent)")
        }

        // Canonical benchmark WAVs already match the pipeline format.
        if audioFile.processingFormat.sampleRate == outputFormat.sampleRate,
           audioFile.processingFormat.channelCount == outputFormat.channelCount {
            var chunks: [AVAudioPCMBuffer] = []
            while audioFile.framePosition < audioFile.length {
                let count = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize),
                                                  audioFile.length - audioFile.framePosition))
                guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                    frameCapacity: count) else {
                    throw FileMicrophoneServiceError.prepareFailed("Could not allocate audio buffer")
                }
                do {
                    try audioFile.read(into: buffer, frameCount: count)
                } catch {
                    throw FileMicrophoneServiceError.audioFileUnreadable(audioURL.lastPathComponent, error)
                }
                guard buffer.frameLength > 0 else {
                    throw FileMicrophoneServiceError.prepareFailed("Unexpected end of audio: \(audioURL.lastPathComponent)")
                }
                chunks.append(buffer)
            }
            return chunks
        }

        guard let converter = AVAudioConverter(from: audioFile.processingFormat, to: outputFormat) else {
            throw FileMicrophoneServiceError.prepareFailed("Could not create audio converter for \(audioURL.lastPathComponent)")
        }
        
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                                 frameCapacity: chunkSize) else {
            throw FileMicrophoneServiceError.prepareFailed("Could not allocate input buffer for \(audioURL.lastPathComponent)")
        }
        
        var chunks: [AVAudioPCMBuffer] = []
        var didReachEndOfInput = false
        var readError: Error?
        
        while true {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                                      frameCapacity: chunkSize) else {
                throw FileMicrophoneServiceError.prepareFailed("Could not allocate output buffer for \(audioURL.lastPathComponent)")
            }
            
            var conversionError: NSError?
            let status = converter.convert(to: outputBuffer,
                                           error: &conversionError) { packetCount, outputStatus in
                if didReachEndOfInput || audioFile.framePosition >= audioFile.length {
                    didReachEndOfInput = true
                    outputStatus.pointee = .endOfStream
                    return nil
                }
                
                do {
                    let remainingFrames = AVAudioFrameCount(min(AVAudioFramePosition(inputBuffer.frameCapacity),
                                                                audioFile.length - audioFile.framePosition))
                    let requestedFrames = min(AVAudioFrameCount(packetCount), remainingFrames)
                    try audioFile.read(into: inputBuffer, frameCount: requestedFrames)
                    
                    guard inputBuffer.frameLength > 0 else {
                        didReachEndOfInput = true
                        outputStatus.pointee = .endOfStream
                        return nil
                    }
                    
                    outputStatus.pointee = .haveData
                    return inputBuffer
                } catch {
                    readError = error
                    outputStatus.pointee = .noDataNow
                    return nil
                }
            }
            
            if let readError {
                throw FileMicrophoneServiceError.audioFileUnreadable(audioURL.lastPathComponent, readError)
            }
            
            if let conversionError {
                throw FileMicrophoneServiceError.audioFileUnreadable(audioURL.lastPathComponent, conversionError)
            }
            
            if outputBuffer.frameLength > 0,
               let copiedBuffer = outputBuffer.copyAudioFixtureBuffer() {
                chunks.append(copiedBuffer)
            }
            
            switch status {
            case .haveData, .inputRanDry:
                if didReachEndOfInput, outputBuffer.frameLength == 0 {
                    return chunks
                }
            case .endOfStream:
                return chunks
            case .error:
                throw FileMicrophoneServiceError.prepareFailed("Audio conversion failed for \(audioURL.lastPathComponent)")
            @unknown default:
                throw FileMicrophoneServiceError.prepareFailed("Unknown audio conversion status for \(audioURL.lastPathComponent)")
            }
        }
    }
    
    private func waitForPlaybackStartIfNeeded() async {
        guard !startsAutomatically else { return }
        
        let shouldWait = lock.synchronized {
            !playbackRequested
        }
        guard shouldWait else { return }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var shouldResumeImmediately = false
            
            lock.lock()
            if playbackRequested {
                shouldResumeImmediately = true
            } else {
                playbackStartContinuation = continuation
            }
            lock.unlock()
            
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }
    
    private func emit(chunks: [AVAudioPCMBuffer],
                      levelHandler: @escaping @Sendable (Double) -> Void,
                      bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) async {
        let clock = ContinuousClock()
        
        for (index, chunk) in chunks.enumerated() {
            guard isCaptureRunning else { return }
            
            bufferHandler(chunk)
            levelHandler(Self.rmsLevel(for: chunk))
            eventContinuation.yield(.chunkEmitted(index: index, at: clock.now))
            
            let seconds = Double(chunk.frameLength) / chunk.format.sampleRate
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
        }
        
        guard isCaptureRunning else { return }
        eventContinuation.yield(.endOfAudio(at: clock.now))
        eventContinuation.finish()
    }
    
    private var isCaptureRunning: Bool {
        lock.synchronized {
            isRunning
        }
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

private extension Bundle {
    func audioFixtureURL(for commandName: String) -> URL? {
        url(forResource: commandName, withExtension: "wav", subdirectory: "Audio")
            ?? url(forResource: commandName, withExtension: "wav")
    }
}

private extension AVAudioPCMBuffer {
    func copyAudioFixtureBuffer() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        
        copy.frameLength = frameLength
        let channelCount = Int(format.channelCount)
        let frameCount = Int(frameLength)
        
        guard let source = floatChannelData,
              let destination = copy.floatChannelData else {
            return nil
        }
        
        for channel in 0..<channelCount {
            destination[channel].update(from: source[channel], count: frameCount)
        }
        
        return copy
    }
}

private extension NSLock {
    func synchronized<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
