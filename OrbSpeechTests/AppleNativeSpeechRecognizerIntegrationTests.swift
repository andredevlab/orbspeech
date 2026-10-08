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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()
        
        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "move left", "Expected 'move left' got '\(stableText)'")
    }

    @Test("Transcribes the bundled centre audio fixture")
    func transcribesCentreFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "centre", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "center", "Expected 'center' got '\(stableText)'")
    }

    @Test("Transcribes the bundled colour_ocean audio fixture")
    func transcribesColourOceanFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "colour_ocean", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "can you become the color of the ocean",
                "Expected 'can you become the color of the ocean' got '\(stableText)'")
    }

    @Test("Transcribes the bundled go_crimson audio fixture")
    func transcribesGoCrimsonFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "go_crimson", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "go crimson", "Expected 'go crimson' got '\(stableText)'")
    }

    @Test("Transcribes the bundled move audio fixture")
    func transcribesMoveFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "move", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "move", "Expected 'move' got '\(stableText)'")
    }

    @Test("Transcribes the bundled move_down audio fixture")
    func transcribesMoveDownFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "move_down", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "move down", "Expected 'move down' got '\(stableText)'")
    }

    @Test("Transcribes the bundled move_top audio fixture")
    func transcribesMoveTopFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "move_top", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "move top", "Expected 'move top' got '\(stableText)'")
    }

    @Test("Transcribes the bundled move_up audio fixture")
    func transcribesMoveUpFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "move_up", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "move up", "Expected 'move up' got '\(stableText)'")
    }

    @Test("Transcribes the bundled shift_right audio fixture")
    func transcribesShiftRightFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "shift_right", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "shift right", "Expected 'shift right' got '\(stableText)'")
    }

    @Test("Transcribes the bundled stop audio fixture")
    func transcribesStopFixture() async throws {
        try await Self.requirePhysicalDeviceAndSpeechAuthorization()

        let audioURL = testBundle.url(forResource: "stop", withExtension: "wav")!
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
        let stableText = await finalResult.stableText.lowercased()
        let volatileText = await finalResult.volatileText.lowercased()

        #expect(volatileText.isEmpty, "Expected empty volatile transcript, got '\(volatileText)'")
        #expect(stableText == "stop", "Expected 'stop' got '\(stableText)'")
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
            Run this opt-in integration test on a configured physical device with Speech Recognition permission granted. 
            If permission was denied, enable it in Settings for the test host app and run the test again.
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
