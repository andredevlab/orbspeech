import Foundation

enum FileMicrophoneServiceError: LocalizedError {
    case audioFileMissing(String)
    case audioFileUnreadable(String, Error)
    case prepareFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .audioFileMissing(let name):
            return "Audio fixture file missing: \(name)"
        case .audioFileUnreadable(let name, let error):
            let underlying = error as NSError
            return "Could not read audio fixture \(name): \(underlying.domain) "
                + "(\(underlying.code)): \(underlying.localizedDescription); \(underlying.userInfo)"
        case .prepareFailed(let reason):
            return "Audio fixture preparation failed: \(reason)"
        case .timeout(let reason):
            return "Audio fixture timed out: \(reason)"
        }
    }
}
