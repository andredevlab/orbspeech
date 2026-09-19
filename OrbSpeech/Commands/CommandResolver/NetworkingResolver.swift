import Foundation

actor NetworkingResolver: CommandResolver {
    func prewarm() async throws {
        
    }
    
    func resolve(_ transcript: String) async throws -> OrbCommand {
        try await Task.sleep(for: .seconds(2))
        throw NetworkingResolverError.unavailable
    }
}

enum NetworkingResolverError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Networking resolver is unavailable."
        }
    }
}
