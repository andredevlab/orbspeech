import Foundation

enum AppleNativeSpeechRecognizerError: LocalizedError {
    case authorizationDenied
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            "Speech permission denied."
        case .recognizerUnavailable:
            "Apple Native Speech Recognizer is unavailable in this device or language."
        }
    }
}
