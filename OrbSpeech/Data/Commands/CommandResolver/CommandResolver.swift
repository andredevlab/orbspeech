import Foundation

nonisolated protocol CommandResolver: Sendable {
    func prewarm() async throws
    func resolve(_ transcript: String) async throws -> OrbCommand
}
