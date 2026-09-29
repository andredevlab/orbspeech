import Foundation

enum SpeakCommand {
    case listening
    case accepted(OrbCommand)
    case cancelled
    case unsupported
    
    var text: String {
        switch self {
        case .listening:
            return "I'm listening."
        case .accepted(let command):
            return acknowledgement(for: command)
        case .cancelled:
            return "Cancelled."
        case .unsupported:
            return "Sorry, I can't do that yet."
        }
    }
    
    private func acknowledgement(for command: OrbCommand) -> String {
        switch command.action {
        case .move:
            guard let target = OrbMoveTarget(command.value) else { return "Ok." }
            switch target {
            case .left, .right:
                return "Ok, moving \(target.rawValue)."
            case .center, .middle:
                return "Ok, centering."
            }
        case .color:
            guard let target = OrbColorTarget(command.value) else { return "Ok." }
            return "Ok, changing color to \(target.rawValue)."
        case .bounce:
            return "Ok, bouncing."
        case .cancel, .unknown:
            return "Ok."
        }
    }
}

@MainActor
protocol SpeakCommandHandling: AnyObject {
    func speak(_ command: SpeakCommand) async
    func stopSpeaking()
}
