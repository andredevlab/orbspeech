import Foundation

@MainActor
protocol VoiceCommandCoordinatorDelegate: AnyObject {
    func voiceCommandCoordinatorDidStartResolving()
    func voiceCommandCoordinatorDidLog(_ message: String)
}
