import Foundation

protocol CommandResolver {
    func resolve(_ transcript: String) async throws -> OrbCommand
}
