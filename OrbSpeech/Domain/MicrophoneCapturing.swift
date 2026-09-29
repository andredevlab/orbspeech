import AVFoundation
import Foundation

enum MicrophoneInterruption: Sendable {
    case began
    case ended(shouldResume: Bool)
}

nonisolated protocol MicrophoneCapturing: Sendable {
    func requestPermission() async -> Bool
    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               interruptionHandler: @escaping @Sendable (MicrophoneInterruption) -> Void) throws
    func stop()
}
