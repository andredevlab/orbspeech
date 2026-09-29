import Foundation

enum OrbMoveTarget: String, Sendable {
    case left
    case center
    case middle
    case right
    
    init?(_ value: String?) {
        guard let value = value?.lowercased() else { return nil }
        self.init(rawValue: value)
    }
    
    var spokenValue: String {
        switch self {
        case .middle:
            return Self.center.rawValue
        case .left, .center, .right:
            return rawValue
        }
    }
}
