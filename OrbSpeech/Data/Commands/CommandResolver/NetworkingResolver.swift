import Foundation

actor NetworkingResolver: CommandResolver {
    func prewarm() async throws {
        
    }
    
    func resolve(_ transcript: String) async throws -> OrbCommand {
        throw NetworkingResolverError.unavailable
    }
}
