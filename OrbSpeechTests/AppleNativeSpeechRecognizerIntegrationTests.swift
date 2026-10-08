import Foundation
import Speech
import Testing

@testable import OrbSpeech

private final class AppleNativeSpeechRecognizerIntegrationBundleToken {}

/// Opt-in integration coverage for Apple's on-device speech recognizer.
///
/// This suite intentionally exercises `AppleNativeSpeechRecognizer` directly,
/// not `SpeechRecognizerFallbackOrchestrator`, so it can never pass through the
/// FluidAudio fallback.
///
/// It is not suitable for the default CI/test-plan gate. Apple Speech depends on
/// system permission state, physical-device runtime availability, and local
/// language assets. On first run, iOS may show the Speech Recognition permission
/// prompt. Choose Allow to execute the test. If permission is denied, this test
/// fails until permission is re-enabled in Settings for the test host app.
@Suite("Apple native speech recognizer integration", .serialized)
struct AppleNativeSpeechRecognizerIntegrationTests {
    let testBundle = Bundle(for: AppleNativeSpeechRecognizerIntegrationBundleToken.self)
    
    @Test("Transcribes the bundled move_left audio fixture")
    func transcribesMoveLeftFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()
        
        let audioURL = testBundle.url(forResource: "move_left", withExtension: "wav")!
        let chunks = try Helper.loadAudioChunks(from: audioURL)
        let sut = AppleNativeSpeechRecognizer()
        
        try await sut.prepare()
        try await sut.startStreaming { _ in }
        
        for chunk in chunks {
            await sut.stream(buffer: AudioBufferBox(chunk))
        }
        
        let audioDuration = try Helper.audioDuration(for: audioURL)
        try await Task.sleep(for: audioDuration)
        
        let finalResult = await sut.finishStreaming()
        let stableText = await finalResult.stableText
        let volatileText = await finalResult.volatileText
        
        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "Move left", "Expected 'Move left' got '\(stableText)'")
    }
    
    // MARK: - Helper Methods
    
    private static func requirePhysicalDeviceAndSpeechAuthorization() async throws {
#if targetEnvironment(simulator)
        try #require(Bool(false), "Apple Speech integration test requires a physical iOS device.")
#endif
        
        let authorization = await Self.requestSpeechAuthorization()
        try #require(authorization == .authorized,
            """
            Apple Speech authorization is \(authorization).
            
            Run this opt-in integration test on a configured physical device with Speech Recognition permission granted. If permission was denied, enable it in Settings for the test host app and run the test again.
            """)
    }
    
    private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
