import Foundation

enum OrbColorTarget: String, Sendable {
    case blue
    case red
    case green
    
    init?(_ value: String?) {
        guard let value = value?.lowercased() else { return nil }
        self.init(rawValue: value)
    }
}
