import Foundation

enum SpeechRecognizerFallbackOrchestratorError: LocalizedError {
    case noActiveRecognizer

    var errorDescription: String? {
        switch self {
        case .noActiveRecognizer:
            "No speech recognizer is active."
        }
    }
}
