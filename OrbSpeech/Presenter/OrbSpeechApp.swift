import SwiftUI
import Factory

@main
@MainActor
struct OrbSpeechApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: OrbSpeechApp.makeViewModel())
        }
    }

    static func makeViewModel() -> ContentViewModel {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let audioURL = environment["ORB_UI_TEST_AUDIO_RESOURCE"].flatMap { resourceName in
            Bundle.main.url(forResource: resourceName, withExtension: "wav")
                ?? Bundle.main.url(forResource: resourceName, withExtension: "wav", subdirectory: "Resources/Audio")
        } ?? environment["ORB_UI_TEST_AUDIO_PATH"].map(URL.init(fileURLWithPath:))

        if let audioURL {
            let transcript = environment["ORB_UI_TEST_TRANSCRIPT"] ?? "move left"

            Container.shared.microphoneCapturing.register {
                UITestAudioFixtureMicrophoneService(audioURL: audioURL)
            }
            Container.shared.speechRecognizer.register {
                UITestSpeechRecognizer(transcript: transcript)
            }
            Container.shared.speechSynthesizer.register {
                MainActor.assumeIsolated {
                    UITestSpeechSynthesizer()
                }
            }
            Container.shared.commandResolver.register {
                UITestCommandResolver()
            }
        }
#endif

        return ContentViewModel()
    }
}
