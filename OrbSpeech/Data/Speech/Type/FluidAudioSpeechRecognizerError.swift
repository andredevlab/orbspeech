import Foundation

enum FluidAudioSpeechRecognizerError: LocalizedError {
    case notReady

    var errorDescription: String? {
        switch self {
        case .notReady:
            "Local CoreML model is not prepared."
        }
    }
}
