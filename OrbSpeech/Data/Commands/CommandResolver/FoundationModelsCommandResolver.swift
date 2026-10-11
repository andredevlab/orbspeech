import Foundation
import FoundationModels

/// Experimental command resolver backed by Apple's on-device Foundation Models.
///
/// This implementation is kept for opt-in investigation and characterization.
/// It is still wired through `CommandResolverFallbackOrchestrator`, but its
/// limitations are documented in `docs/DISCOVERIES.md`.
actor FoundationModelsCommandResolver: CommandResolver {
    private let model: SystemLanguageModel
    private let session: LanguageModelSession
    private var isPrewarmed: Bool = false
    private nonisolated static let instructions =
        """
        You classify short English speech transcripts into exactly one command label.

        Every label is equally valid. Pick the one that describes the transcript.

        Labels:
        - color_blue, color_red, color_green: the transcript names one of these three exact colors.
        - unsupported_color: the transcript names any other color (yellow, purple, crimson, orange, pink, black, white, teal, maroon, navy, gold, silver, brown).
        - move_left, move_center, move_right: the transcript asks to move (with or without a specific supported direction).
        - bounce: the transcript asks for a bounce.
        - cancel: the transcript asks to stop or cancel.
        - unknown_request: the transcript is not about a color or movement (shapes, objects, food, weather, unrelated).

        Examples:
        "go green"          => color_green
        "turn blue"         => color_blue
        "go crimson"        => unsupported_color
        "paint it orange"   => unsupported_color
        "make it pink"      => unsupported_color
        "turn black"        => unsupported_color
        "go yellow"         => unsupported_color
        "turn purple"       => unsupported_color
        "move left"         => move_left
        "shift right"       => move_right
        "centre yourself"   => move_center
        "go somewhere"      => move_center
        "give me a bounce"  => bounce
        "stop"              => cancel
        "make a square"     => unknown_request
        "what is the weather" => unknown_request
        """
    private nonisolated static let supportedCommandValues = [
        "move_left",
        "move_center",
        "move_right",
        "color_blue",
        "color_red",
        "color_green",
        "bounce",
        "cancel",
        "unsupported_color",
        "unknown_request"
    ]
    
    init() {
        let model = SystemLanguageModel.default
        self.model = model
        session = LanguageModelSession(model: model, instructions: Self.instructions)
    }
    
    func prewarm() throws {
        guard !isPrewarmed else { return }

        try ensureModelIsAvailable()
        session.prewarm()
        isPrewarmed = true
    }
    
    func resolve(_ transcript: String) async throws -> OrbCommand {
        try ensureModelIsAvailable()
        
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw FoundationModelsCommandResolverError.emptyTranscript
        }

        let commandInstructions = "Transcript: \"\(cleanTranscript)\""

        let response = try await session
            .respond(to: commandInstructions,
                     schema: Self.commandSchema(),
                     options: GenerationOptions(sampling: .greedy,
                                                temperature: 0,
                                                maximumResponseTokens: 40))
        
        let command = try response.content
            .value(String.self, forProperty: "command")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return Self.orbCommand(for: command)
    }
    
    private static func commandSchema() -> GenerationSchema {
        GenerationSchema(type: GeneratedContent.self,
                         description: "A single orb command classification.",
                         properties: [
                            // `target` is declared here to anchor the model on the literal target
                            // word before it picks a label. It is intentionally not read in
                            // `resolve`.
                            GenerationSchema.Property(name: "target",
                                                      description: "The literal target word from the transcript (a color, a direction, a shape, or 'none').",
                                                      type: String.self),
                            GenerationSchema.Property(name: "command",
                                                      description: "Final command label.",
                                                      type: String.self,
                                                      guides: [.anyOf(supportedCommandValues)])])
    }
    
    private func ensureModelIsAvailable() throws {
        switch model.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw FoundationModelsCommandResolverError.modelUnavailable(reason)
        }
    }
    
    nonisolated private static func orbCommand(for command: String) -> OrbCommand {
        switch command {
        case "move_left":
            OrbCommand(action: .move, value: OrbMoveTarget.left.rawValue)
        case "move_center":
            OrbCommand(action: .move, value: OrbMoveTarget.center.rawValue)
        case "move_right":
            OrbCommand(action: .move, value: OrbMoveTarget.right.rawValue)
        case "color_blue":
            OrbCommand(action: .color, value: OrbColorTarget.blue.rawValue)
        case "color_red":
            OrbCommand(action: .color, value: OrbColorTarget.red.rawValue)
        case "color_green":
            OrbCommand(action: .color, value: OrbColorTarget.green.rawValue)
        case "bounce":
            OrbCommand(action: .bounce)
        case "cancel":
            OrbCommand(action: .cancel)
        case "unsupported_color", "unknown_request":
            OrbCommand(action: .unknown)
        default:
            OrbCommand(action: .unknown)
        }
    }
}
