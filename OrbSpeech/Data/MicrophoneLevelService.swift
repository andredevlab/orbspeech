import AVFoundation
import Foundation

final class MicrophoneService: MicrophoneCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "rumi.microphone.level")
    private var levelHandler: (@Sendable (Double) -> Void)?
    private var bufferHandler: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var interruptionHandler: (@Sendable (MicrophoneInterruption) -> Void)?
    private var interruptionObserver: NSObjectProtocol?
    private var smoothedLevel: Double = 0
    
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
    
    func start(levelHandler: @escaping @Sendable (Double) -> Void,
               bufferHandler: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
               interruptionHandler: @escaping @Sendable (MicrophoneInterruption) -> Void) throws {
        self.levelHandler = levelHandler
        self.bufferHandler = bufferHandler
        self.interruptionHandler = interruptionHandler
        smoothedLevel = 0
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker])
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        observeAudioSessionInterruptions()
        
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }
        
        engine.prepare()
        try engine.start()
    }
    
    func stop() {
        stopCapture(deactivateSession: true)
        clearInterruptionHandling()
    }
    
    private func stopCapture(deactivateSession: Bool) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        levelHandler = nil
        bufferHandler = nil
        smoothedLevel = 0
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }
    
    private func observeAudioSessionInterruptions() {
        removeAudioSessionInterruptionObserver()
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                      object: AVAudioSession.sharedInstance(),
                                                                      queue: .main) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification)
        }
    }
    
    private func removeAudioSessionInterruptionObserver() {
        guard let interruptionObserver else { return }
        NotificationCenter.default.removeObserver(interruptionObserver)
        self.interruptionObserver = nil
    }
    
    private func clearInterruptionHandling() {
        removeAudioSessionInterruptionObserver()
        interruptionHandler = nil
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }
        
        switch type {
        case .began:
            stopCapture(deactivateSession: false)
            interruptionHandler?(.began)
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            interruptionHandler?(.ended(shouldResume: options.contains(.shouldResume)))
            clearInterruptionHandling()
        @unknown default:
            return
        }
    }
    
    private func handle(buffer: AVAudioPCMBuffer) {
        if let copiedBuffer = buffer.copyPCMBuffer() {
            bufferHandler?(copiedBuffer)
        }
        
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameLength > 0, channelCount > 0 else { return }
        
        queue.async { [weak self] in
            var sumSquares: Double = 0
            let sampleCount = frameLength * channelCount
            
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for frame in 0..<frameLength {
                    let sample = Double(samples[frame])
                    sumSquares += sample * sample
                }
            }
            
            let rms = sqrt(sumSquares / Double(sampleCount))
            let avgPower = 20 * log10(max(rms, 0.000_000_1))
            let nextLevel = max(0.0, min(1.0, (avgPower + 80) / 80))
            
            guard let self else { return }
            self.smoothedLevel += (nextLevel - self.smoothedLevel) * 0.15
            self.levelHandler?(self.smoothedLevel)
        }
    }
}

private extension AVAudioPCMBuffer {
    func copyPCMBuffer() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        
        copy.frameLength = frameLength
        let channelCount = Int(format.channelCount)
        let frameCount = Int(frameLength)
        
        if let source = floatChannelData, let destination = copy.floatChannelData {
            for channel in 0..<channelCount {
                destination[channel].update(from: source[channel], count: frameCount)
            }
            return copy
        }
        
        return nil
    }
}
