import Factory

extension Container {
    var microphoneCapturing: Factory<any MicrophoneCapturing> {
        self { MicrophoneService() as any MicrophoneCapturing }
    }

    var speechRecognizer: Factory<any SpeechRecognizer> {
        self { SpeechRecognizerFallbackOrchestrator() as any SpeechRecognizer }
    }

    var speechSynthesizer: Factory<any SpeechSynthesizing> {
        self {
            MainActor.assumeIsolated {
                OrbSpeechSynthesizer() as any SpeechSynthesizing
            }
        }
    }

    var commandResolver: Factory<any CommandResolver> {
        self { CommandResolverFallbackOrchestrator() as any CommandResolver }
    }
}
