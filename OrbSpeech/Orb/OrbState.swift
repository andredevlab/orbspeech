import Foundation

enum OrbState: Equatable {
    case idle
    case listening(Double)
    case thinking
    case settling
    
    var description: String {
        switch self {
        case .idle:
            "Waiting"
        case .listening(let level):
            "Listening - voice level: \(level)"
        case .thinking:
            "Thinking"
        case .settling:
            "Settling"
        }
    }
}
