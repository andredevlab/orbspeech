import Foundation
import Testing

@testable import OrbSpeech

/// Opt-in integration coverage for Apple's on-device Foundation Models command resolver.
///
/// This suite intentionally exercises `FoundationModelsCommandResolver` directly,
/// not `CommandResolverFallbackOrchestrator`, so no fallback can mask Foundation
/// Models availability, authorization, or resolution failures.
///
/// It is not suitable for the default test-plan gate. Run it only on a real
/// Apple Intelligence-capable device or Mac with Apple Intelligence enabled and
/// the local Foundation Models assets fully downloaded. Simulators may compile
/// and start the test, but they can fail at generation time when the local Model
/// Catalog assets are unavailable.
///
/// On first run, the OS may show an Apple Intelligence prompt. Accept it to
/// execute the test. If Apple Intelligence is disabled, the model is not ready,
/// or the runtime cannot provide Foundation Models assets, this test fails
/// explicitly.
@MainActor
@Suite("Foundation Models command resolver integration", .serialized)
struct FoundationModelsCommandResolverIntegrationTests {
    let sut = FoundationModelsCommandResolver()
    
    struct CommandExpectation: Sendable {
        let transcript: String
        let action: OrbCommandAction
        let value: String?
    }
    
    @Test("Resolves supported command transcripts",
          arguments: [CommandExpectation(transcript: "move left",
                                         action: .move,
                                         value: OrbMoveTarget.left.rawValue),
                      CommandExpectation(transcript: "shift right",
                                         action: .move,
                                         value: OrbMoveTarget.right.rawValue),
                      CommandExpectation(transcript: "go left",
                                         action: .move,
                                         value: OrbMoveTarget.left.rawValue),
                      CommandExpectation(transcript: "go right",
                                         action: .move,
                                         value: OrbMoveTarget.right.rawValue),
                      CommandExpectation(transcript: "centre yourself",
                                         action: .move,
                                         value: OrbMoveTarget.center.rawValue),
                      CommandExpectation(transcript: "turn blue",
                                         action: .color,
                                         value: OrbColorTarget.blue.rawValue),
                      CommandExpectation(transcript: "go blue",
                                         action: .color,
                                         value: OrbColorTarget.blue.rawValue),
                      CommandExpectation(transcript: "go green",
                                         action: .color,
                                         value: OrbColorTarget.green.rawValue),
                      CommandExpectation(transcript: "turn red",
                                         action: .color,
                                         value: OrbColorTarget.red.rawValue),
                      CommandExpectation(transcript: "give me a bounce",
                                         action: .bounce,
                                         value: nil),
                      CommandExpectation(transcript: "stop",
                                         action: .cancel,
                                         value: nil),
                      CommandExpectation(transcript: "can you become the color of the ocean",
                                         action: .color,
                                         value: OrbColorTarget.blue.rawValue)])
    func resolvesSupportedCommandTranscripts(expectation: CommandExpectation) async throws {
        try await sut.prewarm()
        
        let command = try await sut.resolve(expectation.transcript)
        let action = command.action
        let value = command.value
        
        #expect(action == expectation.action,
                "Expected action '\(expectation.action.rawValue)' for '\(expectation.transcript)', got '\(action.rawValue)'")
        #expect(value == expectation.value,
                "Expected value '\(String(describing: expectation.value))' for '\(expectation.transcript)', got '\(String(describing: value))'")
    }
    
    @Test("Resolves vague movement requests to a supported move command",
          arguments: ["move somewhere",
                      "go to another spot"])
    func resolvesVagueMovementRequests(transcript: String) async throws {
        try await sut.prewarm()
        
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        #expect(action == .move,
                "Expected action 'move' for '\(transcript)', got '\(action.rawValue)'")
        #expect([OrbMoveTarget.left.rawValue,
                 OrbMoveTarget.center.rawValue,
                 OrbMoveTarget.right.rawValue].contains(value),
                "Expected a supported move target for '\(transcript)', got '\(String(describing: value))'")
    }
    
    @Test("Refuses unsupported command targets",
          arguments: ["go crimson",
                      "go yellow",
                      "make a square"])
    func refusesUnsupportedCommandTargets(transcript: String) async throws {
        try await sut.prewarm()
        
        let command = try await sut.resolve(transcript)
        let action = command.action
        let value = command.value
        
        #expect(action == .unknown,
                "Expected action 'unknown' for '\(transcript)', got '\(action.rawValue)'")
        #expect(value == nil,
                "Expected nil value for unsupported transcript '\(transcript)', got '\(String(describing: value))'")
    }
}
