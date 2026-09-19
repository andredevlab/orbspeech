import CoreML
import Foundation

actor CoreMLModelCommandResolver: CommandResolver {
    private let bundledModelName = "OrbCommandClassifier"
    private var model: MLModel?

    func prewarm() throws {
        model = try loadBundledModel()
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            throw CoreMLModelCommandResolverError.emptyTranscript
        }

        let loadedModel: MLModel
        if let model {
            loadedModel = model
        } else {
            model = try loadBundledModel()
            loadedModel = model!
        }

        let input = try MLDictionaryFeatureProvider(dictionary: ["text": cleanTranscript])
        let output = try await loadedModel.prediction(from: input)
        guard let label = output.featureValue(for: "label")?.stringValue else {
            throw CoreMLModelCommandResolverError.missingOutputLabel
        }

        return Self.command(for: label)
    }

    private func loadBundledModel() throws -> MLModel {
        guard let modelURL = Bundle.main.url(forResource: bundledModelName, withExtension: "mlmodelc") else {
            throw CoreMLModelCommandResolverError.modelMissing(bundledModelName)
        }

        return try MLModel(contentsOf: modelURL)
    }

    nonisolated private static func command(for label: String) -> OrbCommand {
        switch label {
        case "move_left":
            return OrbCommand(id: UUID().uuidString, action: "move", value: "left")
        case "move_right":
            return OrbCommand(id: UUID().uuidString, action: "move", value: "right")
        case "move_center":
            return OrbCommand(id: UUID().uuidString, action: "move", value: "center")
        case "color_blue":
            return OrbCommand(id: UUID().uuidString, action: "color", value: "blue")
        case "color_red":
            return OrbCommand(id: UUID().uuidString, action: "color", value: "red")
        case "color_green":
            return OrbCommand(id: UUID().uuidString, action: "color", value: "green")
        case "bounce":
            return OrbCommand(id: UUID().uuidString, action: "bounce", value: nil)
        case "cancel":
            return OrbCommand(id: UUID().uuidString, action: "cancel", value: nil)
        default:
            return OrbCommand(id: UUID().uuidString, action: "unknown", value: nil)
        }
    }

}

enum CoreMLModelCommandResolverError: LocalizedError {
    case emptyTranscript
    case modelMissing(String)
    case missingOutputLabel

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            "No transcript to resolve."
        case .modelMissing(let name):
            "Core ML command model missing: \(name).mlmodelc."
        case .missingOutputLabel:
            "Core ML command model did not return a label."
        }
    }
}
