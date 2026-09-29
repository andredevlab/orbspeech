import Foundation

struct OrbCommand: Sendable {
    let id: String
    let action: OrbCommandAction
    let value: String?
    
    nonisolated init(id: String = UUID().uuidString,
                     action: OrbCommandAction,
                     value: String? = nil) {
        self.id = id
        self.action = action
        self.value = value
    }
    
    nonisolated init(id: String = UUID().uuidString,
                     actionRawValue: String,
                     value: String? = nil) {
        self.id = id
        self.action = OrbCommandAction(rawValue: actionRawValue) ?? .unknown
        self.value = value
    }
}
