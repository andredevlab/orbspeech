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
