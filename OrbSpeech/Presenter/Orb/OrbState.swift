import Foundation

enum OrbState: Equatable {
    case idle
    case listening(Double)
    case thinking
    case settling
    case speaking
    case acting
    
    var description: String {
        switch self {
        case .idle:
            "Waiting"
        case .listening(let level):
            "Listening - voice level: \(String(format: "%.3f", level))"
        case .thinking:
            "Thinking"
        case .settling:
            "Settling"
        case .speaking:
            "Speaking"
        case .acting:
            "Acting"
        }
    }
}
