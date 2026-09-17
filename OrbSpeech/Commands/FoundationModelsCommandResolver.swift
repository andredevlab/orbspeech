import Foundation
import FoundationModels

actor FoundationModelsCommandResolver: CommandResolver {
    private let model: SystemLanguageModel
    private let session: LanguageModelSession

    init() {
        let model = SystemLanguageModel(useCase: .contentTagging)
        self.model = model
        session = LanguageModelSession(
            model: model,
            instructions: """
            You turn short English speech transcripts into orb commands.
            Return only a structured command.
            Use action "move" for position changes.
            Use action "color" for color changes.
            Use action "bounce" for bounce requests.
            Use action "unknown" when the transcript is not something the orb can do.
            Keep value short: left, center, right, blue, red, green, or nil when not needed.
            """
        )
    }

    func prewarm() throws {
        try ensureModelIsAvailable()
        session.prewarm()
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        try ensureModelIsAvailable()

        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw FoundationModelsCommandResolverError.emptyTranscript
        }

        let response = try await session.respond(
            to: """
            Transcript: "\(cleanTranscript)"

            Resolve this transcript into one orb command.
            If the transcript does not clearly request a supported orb action, use action "unknown" and value nil.
            """,
            schema: Self.commandSchema,
            options: GenerationOptions(
                sampling: .greedy,
                temperature: 0,
                maximumResponseTokens: 40
            )
        )

        let content = response.content
        let id = try content.value(String?.self, forProperty: "id")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let action = try content.value(String.self, forProperty: "action")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let value = try content.value(String?.self, forProperty: "value")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return OrbCommand(
            id: id?.isEmpty == false ? id! : UUID().uuidString,
            action: Self.normalizedAction(action),
            value: value?.isEmpty == false ? value : nil
        )
    }

    private func ensureModelIsAvailable() throws {
        switch model.availability {
        case .available:
            return
        case .unavailable(let reason):
            throw FoundationModelsCommandResolverError.modelUnavailable(reason)
        }
    }

    nonisolated private static func normalizedAction(_ action: String) -> String {
        switch action {
        case "move", "color", "bounce":
            action
        default:
            "unknown"
        }
    }

    private static let commandSchema = GenerationSchema(
        type: GeneratedContent.self,
        description: "A command the orb app can attempt to perform.",
        properties: [
            GenerationSchema.Property(
                name: "id",
                description: "A short unique id for this command.",
                type: String.self
            ),
            GenerationSchema.Property(
                name: "action",
                description: "The requested orb action.",
                type: String.self,
                guides: [.anyOf(["move", "color", "bounce", "unknown"])]
            ),
            GenerationSchema.Property(
                name: "value",
                description: "The target value for the action, or nil if no value is needed.",
                type: String?.self
            )
        ]
    )
}

enum FoundationModelsCommandResolverError: LocalizedError {
    case emptyTranscript
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            "No transcript to resolve."
        case .modelUnavailable(let reason):
            "Apple on-device language model unavailable: \(reason.detail)."
        }
    }
}

private extension SystemLanguageModel.Availability.UnavailableReason {
    var detail: String {
        switch self {
        case .deviceNotEligible:
            "device not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence not enabled"
        case .modelNotReady:
            "model not ready"
        @unknown default:
            "unknown reason"
        }
    }
}
