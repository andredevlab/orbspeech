import CoreML
import Foundation

actor CoreMLModelCommandResolver: CommandResolver {
    private let bundledModelName = "OrbCommandClassifier"
    private var model: MLModel?

    func prewarm() throws {
        model = try loadBundledModel()
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        let cleanTranscript = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
        guard let commandLabel = CoreMLCommandLabel(rawValue: label) else {
            return OrbCommand(action: .unknown)
        }
        
        switch commandLabel {
        case .moveLeft:
            return OrbCommand(action: .move, value: OrbMoveTarget.left.rawValue)
        case .moveRight:
            return OrbCommand(action: .move, value: OrbMoveTarget.right.rawValue)
        case .moveCenter:
            return OrbCommand(action: .move, value: OrbMoveTarget.center.rawValue)
        case .colorBlue:
            return OrbCommand(action: .color, value: OrbColorTarget.blue.rawValue)
        case .colorRed:
            return OrbCommand(action: .color, value: OrbColorTarget.red.rawValue)
        case .colorGreen:
            return OrbCommand(action: .color, value: OrbColorTarget.green.rawValue)
        case .bounce:
            return OrbCommand(action: .bounce)
        case .cancel:
            return OrbCommand(action: .cancel)
        }
    }
}
