import Foundation
import Testing

@testable import OrbSpeech

/// Characterization tests for semantic approximation in the on-device
/// Foundation Model. These tests document behaviors where the model
/// collapses an unsupported target to a semantically close supported
/// target, instead of emitting `unsupported_color` or `unknown_request`.
///
/// These tests are not assertions that the behavior is correct. They
/// are assertions that the behavior is *current*. If the model changes
/// and these tests fail, the failure is a signal to re-evaluate the
/// documented limitation in `docs/DISCOVERIES.md`.
///
/// The approximation is verb-context dependent: `turn purple` collapses
/// to `color_blue`, but `go purple` and `become purple` emit `unknown`.
/// The geometric proximity of `purple` to `blue` is a necessary but not
/// sufficient condition for the collapse. See `docs/DISCOVERIES.md`.
///
/// Opt-in, same as `FoundationModelsCommandResolverIntegrationTests`.
/// Run only on a real Apple Intelligence-capable Mac.
@MainActor
@Suite("Foundation Models semantic approximation", .serialized)
struct FoundationModelsCommandResolverSemanticApproximationTests {
    let sut = FoundationModelsCommandResolver()
    
    @Test("`turn purple` collapses to a supported color")
    func turnPurpleCollapsesToSupportedColor() async throws {
        try await sut.prewarm()
        let command = try await sut.resolve("turn purple")
        let action = command.action
        let value = command.value
        
        // Observed behavior: `turn` primes a strong `verb -> color`
        // association, and `purple` is geometrically close enough to
        // `blue` that the model picks `color_blue` instead of
        // `unsupported_color`. The geometric proximity alone is not
        // sufficient; the verb context is what triggers the collapse.
        #expect(action == .color,
                "Expected 'turn purple' to collapse to a color action, got '\(action.rawValue)'")
        #expect(value == OrbColorTarget.blue.rawValue,
                "Expected 'turn purple' to collapse to 'blue', got '\(String(describing: value))'")
    }
    
    @Test("`go purple` and `become purple` do not collapse to a supported color",
          arguments: ["go purple", "become purple"])
    func nonTurnPurpleEmitsUnknown(transcript: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        
        // Counterpoint to the `turn purple` case: for verbs other than
        // `turn`, the model emits `unknown` correctly. This is what
        // shows the collapse is verb-context dependent, not purely
        // geometric.
        #expect(action == .unknown,
                "Expected '\(transcript)' to emit unknown, got '\(action.rawValue)'")
    }
    
    @Test("Unsupported colors with no close supported neighbor emit unknown",
          arguments: ["go yellow", "go crimson"])
    func distantColorsEmitUnknown(transcript: String) async throws {
        try await sut.prewarm()
        let command = try await sut.resolve(transcript)
        let action = command.action
        
        #expect(action == .unknown,
                "Expected distant color to emit unknown, got '\(action.rawValue)' for '\(transcript)'")
    }
}
