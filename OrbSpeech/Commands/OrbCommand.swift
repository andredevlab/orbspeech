import Foundation

struct OrbCommand {
    let id: String
    let action: String
    let value: String?
}

struct CommandOutcome {
    let id: String
    let status: String
    let detail: String?
}

protocol CommandResolver {
    func resolve(_ transcript: String) async throws -> OrbCommand
}
