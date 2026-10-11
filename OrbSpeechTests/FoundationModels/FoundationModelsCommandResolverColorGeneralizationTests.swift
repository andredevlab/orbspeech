import Foundation
import Testing

@testable import OrbSpeech

/// Characterization tests for color generalization in the on-device
/// Foundation Model. These tests assert the *current observed behavior*,
/// not the ideal behavior. They are designed to pass 100% and to fail
/// when the model's behavior changes, signaling that the documented
/// limitations in `docs/DISCOVERIES.md` may need to be re-evaluated.
///
/// The tests are organized into six groups:
///
/// - 1a. Metaphors the model handles correctly.
/// - 1b. Metaphors the model does NOT handle (documented limitation).
/// - 2a. Uncommon color words the model handles correctly.
/// - 2b. Uncommon color words the model does NOT handle (documented limitation).
/// - 3a. Unsupported colors that correctly stay `unknown`.
/// - 3b. Unsupported colors that regress to a supported color (documented regression).
///
/// Group 3b is the most important: it asserts that the model violates the
/// documented `unsupported_color` boundary for shade names that are
/// semantically close to a supported color (`navy -> blue`, `teal -> blue`,
/// `coral -> red`, `olive -> green`).
///
/// Opt-in, same as `FoundationModelsCommandResolverIntegrationTests`.
/// Run only on a real Apple Intelligence-capable Mac.
@MainActor
@Suite("Foundation Models color generalization", .serialized)
struct FoundationModelsCommandResolverColorGeneralizationTests {
    let sut = FoundationModelsCommandResolver()
    
    // MARK: - Group 1a: Metaphors the model handles correctly
    
    @Test("Metaphors the model handles correctly",
          arguments: [("the color of the ocean", OrbColorTarget.blue.rawValue),
                      ("the color of the sky", OrbColorTarget.blue.rawValue),
                      ("the color of midnight", OrbColorTarget.blue.rawValue),
                      ("the color of grass", OrbColorTarget.green.rawValue),
                      ("the color of leaves", OrbColorTarget.green.rawValue),
                      ("the color of fire", OrbColorTarget.red.rawValue)])
    func metaphorsHandled(transcript: String, expectedValue: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        #expect(action == .color,
                "Expected color action for '\(transcript)', got '\(action.rawValue)'")
        #expect(value == expectedValue,
                "Expected '\(expectedValue)' for '\(transcript)', got '\(String(describing: value))'")
    }
    
    // MARK: - Group 1b: Metaphors the model does NOT handle
    
    @Test("Metaphors the model does NOT handle (documented limitation)",
          arguments: ["the color of water",
                      "the color of blood"])
    func metaphorsNotHandled(transcript: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        // Observed: the model returns `unknown` for these metaphors, even
        // though a human would map them to blue and red respectively. This
        // is a documented limitation. If the model starts handling these,
        // this test will fail and the limitation should be re-evaluated.
        #expect(action == .unknown,
                "Expected '\(transcript)' to stay unknown (documented limitation), got '\(action.rawValue)' with value '\(String(describing: value))'")
    }
    
    // MARK: - Group 2a: Uncommon color words the model handles correctly
    
    @Test("Uncommon color words the model handles correctly",
          arguments: [("cobalt", OrbColorTarget.blue.rawValue),
                      ("sapphire", OrbColorTarget.blue.rawValue),
                      ("cerulean", OrbColorTarget.blue.rawValue),
                      ("ruby", OrbColorTarget.red.rawValue),
                      ("jade", OrbColorTarget.green.rawValue)])
    func uncommonColorsHandled(transcript: String, expectedValue: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        #expect(action == .color,
                "Expected color action for '\(transcript)', got '\(action.rawValue)'")
        #expect(value == expectedValue,
                "Expected '\(expectedValue)' for '\(transcript)', got '\(String(describing: value))'")
    }
    
    // MARK: - Group 2b: Uncommon color words the model does NOT handle
    
    @Test("Uncommon color words the model does NOT handle (documented limitation)",
          arguments: ["vermillion",
                      "lime",
                      "mint"])
    func uncommonColorsNotHandled(transcript: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        // Observed: the model returns `unknown` for these color words, even
        // though a human would map them to red, green, and green respectively.
        // Documented limitation. If the model starts handling these, this
        // test will fail and the limitation should be re-evaluated.
        #expect(action == .unknown,
                "Expected '\(transcript)' to stay unknown (documented limitation), got '\(action.rawValue)' with value '\(String(describing: value))'")
    }
    
    // MARK: - Group 3a: Unsupported colors that correctly stay unknown
    
    @Test("Unsupported colors that correctly stay unknown",
          arguments: ["go magenta",
                      "go crimson",
                      "go maroon"])
    func unsupportedStaysUnknown(transcript: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        // These words are documented unsupported color boundaries and the
        // model correctly returns `unknown` for them.
        #expect(action == .unknown,
                "Expected '\(transcript)' to stay unknown, got '\(action.rawValue)' with value '\(String(describing: value))'")
    }
    
    // MARK: - Group 3b: Unsupported colors that regress to a supported color
    
    @Test("Unsupported colors that regress to a supported color (documented regression)",
          arguments: [("go navy", OrbColorTarget.blue.rawValue),
                      ("go teal", OrbColorTarget.blue.rawValue),
                      ("go coral", OrbColorTarget.red.rawValue),
                      ("go olive", OrbColorTarget.green.rawValue)])
    func unsupportedRegressesToSupported(transcript: String, observedValue: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        // Observed: the model collapses these unsupported shade names to
        // their base color. This violates the unsupported-color boundary
        // documented for this investigation.
        //
        // The model treats shade names as their base color. This behavior
        // cannot be fixed by prompt engineering, because it is a property
        // of the model's internal representation, not of the instructions.
        //
        // If the model stops doing this, the test will fail and this
        // documented regression can be removed.
        #expect(action == .color,
                "Expected '\(transcript)' to regress to a color action (documented regression), got '\(action.rawValue)'")
        #expect(value == observedValue,
                "Expected '\(transcript)' to regress to '\(observedValue)' (documented regression), got '\(String(describing: value))'")
    }
}
