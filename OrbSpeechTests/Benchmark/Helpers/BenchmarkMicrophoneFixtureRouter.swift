import AVFoundation
import Foundation
@testable import OrbSpeech

final class BenchmarkMicrophoneFixtureRouter: MicrophoneCapturing, @unchecked Sendable {
    private struct Handlers {
        let level: @Sendable (Double) -> Void
        let buffer: @Sendable (AVAudioPCMBuffer) -> Void
        let interruption: @Sendable (MicrophoneInterruption) -> Void
    }

    private let lock = NSLock()
    private var current: FileMicrophoneService?
    private var handlers: Handlers?

    func select(_ microphone: FileMicrophoneService) throws {
        let previous = lock.synchronized { current }
        let activeHandlers = lock.synchronized { handlers }
        previous?.stop()
        lock.synchronized {
            current = microphone
        }

        guard let activeHandlers else { return }
        do {
            try microphone.start(levelHandler: activeHandlers.level,
                                 bufferHandler: activeHandlers.buffer,
                                 interruptionHandler: activeHandlers.interruption)
        } catch {
            lock.synchronized {
                handlers = nil
            }
            throw error
        }
    }

    func beginPlayback() {
        let microphone = lock.synchronized { current }
        microphone?.beginPlayback()
    }

    func requestPermission() async -> Bool {
        true
    }

    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               interruptionHandler: @escaping @Sendable (MicrophoneInterruption) -> Void) throws {
        let activeHandlers = Handlers(level: levelHandler,
                                      buffer: bufferHandler,
                                      interruption: interruptionHandler)
        let microphone = lock.synchronized {
            handlers = activeHandlers
            return current
        }
        guard let microphone else {
            lock.synchronized {
                handlers = nil
            }
            throw BenchmarkError.prepareFailed("No benchmark microphone selected")
        }
        do {
            try microphone.start(levelHandler: activeHandlers.level,
                                 bufferHandler: activeHandlers.buffer,
                                 interruptionHandler: activeHandlers.interruption)
        } catch {
            lock.synchronized {
                handlers = nil
            }
            throw error
        }
    }

    func stop() {
        let microphone = lock.synchronized {
            handlers = nil
            let microphone = current
            current = nil
            return microphone
        }
        microphone?.stop()
    }
}

private extension NSLock {
    func synchronized<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
