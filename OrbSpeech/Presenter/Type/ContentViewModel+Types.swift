import Foundation

extension ContentViewModel {
    enum OnDeviceComponentsState {
        case idle, loading, success, failed
    }
    
    enum ListeningSessionState {
        case idle
        case active
        case interrupted
    }
    
    enum ViewStatus {
        case idle
        case interrupted
        case ready
        case paused
        case microphonePermissionRequired
        case orb(OrbState)
        case commandOutcome(CommandOutcomeStatus)
        case message(String)
        
        var text: String {
            switch self {
            case .idle:
                return "idle"
            case .interrupted:
                return "interrupted"
            case .ready:
                return "ready"
            case .paused:
                return "paused"
            case .microphonePermissionRequired:
                return "You should allow microphone permission."
            case .orb(let state):
                return state.description
            case .commandOutcome(let status):
                return status.rawValue
            case .message(let text):
                return text
            }
        }
    }
}
