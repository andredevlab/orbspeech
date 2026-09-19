import AVFoundation
import Foundation

nonisolated protocol MicrophoneCapturing: Sendable {
    func requestPermission() async -> Bool
    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws
    func stop()
}
