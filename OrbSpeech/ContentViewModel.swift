import Combine
import Foundation

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var orbState = OrbState.idle
    @Published private(set) var isListening = false
    @Published private(set) var statusText = "idle"

    private let microphone = MicrophoneLevelService()

    func interact() async {
        isListening ? stopListening() : await startListening()
    }

    private func startListening() async {
        let allowed = await microphone.requestPermission()
        guard allowed else {
            statusText = "microphone denied"
            orbState = .idle
            return
        }

        do {
            try microphone.start { [weak self] level in
                guard let self else { return }
                Task { @MainActor in
                    self.isListening = true
                    self.statusText = "listening"
                    self.orbState = .listening(level)
                    print(level)
                }
            }

            isListening = true
            statusText = "listening"
            orbState = .listening(0)
        } catch {
            isListening = false
            statusText = "microphone unavailable"
            orbState = .idle
        }
    }

    private func stopListening() {
        microphone.stop()
        isListening = false
        statusText = "idle"
        orbState = .idle
    }
}
