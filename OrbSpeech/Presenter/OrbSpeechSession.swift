import Observation

@MainActor
@Observable
final class OrbSpeechSession {
    static let shared = OrbSpeechSession()

    // Mutable hook reserved for in-process benchmark experiments.
    var viewModel = OrbSpeechApp.makeViewModel()

    private init() {}
}
