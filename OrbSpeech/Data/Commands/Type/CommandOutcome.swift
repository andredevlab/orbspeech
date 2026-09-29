import Foundation

struct CommandOutcome: Sendable {
    let id: String
    let status: CommandOutcomeStatus
    let detail: String?
    
    nonisolated init(id: String,
                     status: CommandOutcomeStatus,
                     detail: String? = nil) {
        self.id = id
        self.status = status
        self.detail = detail
    }
}
