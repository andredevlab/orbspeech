import CoreML
import Foundation

actor CoreMLModelCommandResolver: CommandResolver {
    private let bundledModelName = "OrbCommandClassifier"
    private var model: MLModel?

    func prewarm() throws {
        model = try? loadBundledModel()
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw CoreMLModelCommandResolverError.emptyTranscript
        }

        if model == nil {
            do {
                model = try loadBundledModel()
            } catch {
                return Self.resolveWithTemporaryLocalFallback(cleanTranscript)
            }
        }

        throw CoreMLModelCommandResolverError.unsupportedModelContract
    }

    private func loadBundledModel() throws -> MLModel {
        guard let modelURL = Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") else {
            throw CoreMLModelCommandResolverError.modelMissing(bundledModelName)
        }

        return try MLModel(contentsOf: modelURL)
    }

    nonisolated private static func resolveWithTemporaryLocalFallback(_ transcript: String) -> OrbCommand {
        let text = transcript
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        if containsAny(text, ["bounce", "jump", "pulse"]) {
            return OrbCommand(id: UUID().uuidString, action: "bounce", value: nil)
        }

        if containsAny(text, ["cancel", "stop", "abort", "never mind", "nevermind"]) {
            return OrbCommand(id: UUID().uuidString, action: "cancel", value: nil)
        }

        if containsAny(text, ["blue", "blu"]) {
            return OrbCommand(id: UUID().uuidString, action: "color", value: "blue")
        }

        if containsAny(text, ["red"]) {
            return OrbCommand(id: UUID().uuidString, action: "color", value: "red")
        }

        if containsAny(text, ["green"]) {
            return OrbCommand(id: UUID().uuidString, action: "color", value: "green")
        }

        if containsAny(text, ["left"]) {
            return OrbCommand(id: UUID().uuidString, action: "move", value: "left")
        }

        if containsAny(text, ["right"]) {
            return OrbCommand(id: UUID().uuidString, action: "move", value: "right")
        }

        if containsAny(text, ["middle", "center", "centre", "back"]) {
            return OrbCommand(id: UUID().uuidString, action: "move", value: "center")
        }

        return OrbCommand(id: UUID().uuidString, action: "unknown", value: nil)
    }

    nonisolated private static func containsAny(_ text: String, _ tokens: [String]) -> Bool {
        tokens.contains { token in
            text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

enum CoreMLModelCommandResolverError: LocalizedError {
    case emptyTranscript
    case modelMissing(String)
    case unsupportedModelContract

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            "No transcript to resolve."
        case .modelMissing(let name):
            "Core ML command model missing: \(name).mlmodelc."
        case .unsupportedModelContract:
            "Core ML command model exists, but its input/output contract is not wired yet."
        }
    }
}
