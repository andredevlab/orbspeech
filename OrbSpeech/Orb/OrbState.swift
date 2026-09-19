import Foundation

enum OrbState: Equatable {
    case idle
    case listening(Double)
    case thinking
    case settling
}
