import Foundation

actor NetworkingResolver: CommandResolver {
    func prewarm() async throws {
        
    }
    
    func resolve(_ transcript: String) async throws -> OrbCommand {
        try await Task.sleep(for: .seconds(2))
        throw NetworkingResolverError.unavailable
    }
}
