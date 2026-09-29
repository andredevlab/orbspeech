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
        switch (command.action, command.value?.lowercased()) {
        case ("move", "left"):
            return "Ok, moving left."
        case ("move", "right"):
            return "Ok, moving right."
        case ("move", "center"), ("move", "middle"):
            return "Ok, centering."
        case ("color", let value?):
            return "Ok, changing color to \(value)."
        case ("bounce", _):
            return "Ok, bouncing."
        default:
            return "Ok."
        }
    }
}

@MainActor
protocol SpeakCommandHandling: AnyObject {
    func speak(_ command: SpeakCommand) async
    func stopSpeaking()
}
