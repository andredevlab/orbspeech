import AVFoundation
import Foundation

@MainActor
final class OrbSpeechSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        stop()

        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        let bestVoice = voices.first(where: { $0.language == "en-US" && $0.quality == .premium })
        ?? voices.first(where: { $0.language == "en-US" && $0.quality == .enhanced })
        ?? AVSpeechSynthesisVoice(language: "en-US")

        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.92
        utterance.volume = 1.0

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finishSpeaking()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            finishSpeaking()
        }
    }

    private func finishSpeaking() {
        continuation?.resume()
        continuation = nil
    }
}
