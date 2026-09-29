import Foundation

enum OrbCommandAction: String, Sendable {
    case move
    case color
    case bounce
    case cancel
    case unknown
    
    var isExecutable: Bool {
        switch self {
        case .move, .color, .bounce:
            return true
        case .cancel, .unknown:
            return false
        }
    }
}
