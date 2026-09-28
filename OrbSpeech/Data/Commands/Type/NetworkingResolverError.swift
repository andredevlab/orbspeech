import Foundation

enum NetworkingResolverError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Networking resolver is unavailable."
        }
    }
}
