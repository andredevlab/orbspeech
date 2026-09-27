import Foundation

@MainActor
protocol SpeechSynthesizing: AnyObject {
    func speak(_ text: String) async
    func stop()
}
