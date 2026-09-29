import CoreML
import Foundation
import Testing
@testable import OrbSpeech

@Suite("OrbCommandClassifier")
struct OrbCommandClassifierTests {
    // Loading the model once at the suite level avoids reopening the MLModel for every parameterized case.
    let classifier = try! Self.loadClassifier()
    
    @Test("Classifies supported commands and returns 'unknown' for ambiguous or unsupported input",
          arguments: [("move left", "move_left"),
                      ("shift right", "move_right"),
                      ("centre", "move_center"),
                      ("stop", "cancel"),
                      ("move", "unknown"),
                      ("move top", "unknown"),
                      ("move up", "unknown"),
                      ("move down", "unknown"),
                      ("go crimson", "unknown"),
                      ("can you become the colour of the ocean", "unknown")])
    func classifiesSupportedCommandsAndFallsBackToUnknown(transcript: String, expectedLabel: String) throws {
        let label = try Self.predictedLabel(for: transcript, using: classifier)
        #expect(label == expectedLabel)
    }
    
    // MARK: - Helpers
    
    private static func loadClassifier() throws -> MLModel {
        let testBundle = Bundle(for: BundleToken.self)
        let appBundleURL = testBundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        guard let appBundle = Bundle(url: appBundleURL) else {
            throw ClassifierTestError.hostBundleUnavailable(testBundlePath: testBundle.bundleURL.path,
                                                            attemptedHostBundlePath: appBundleURL.path)
        }
        
        guard let modelURL = appBundle.url(forResource: "OrbCommandClassifier",
                                           withExtension: "mlmodelc") else {
            throw ClassifierTestError.modelMissing(resource: "OrbCommandClassifier.mlmodelc",
                                                   bundlePath: appBundle.bundleURL.path)
        }
        
        return try MLModel(contentsOf: modelURL)
    }
    
    private static func predictedLabel(for transcript: String,
                                       using classifier: MLModel) throws -> String {
        let input = try MLDictionaryFeatureProvider(dictionary: ["text": transcript])
        let output = try classifier.prediction(from: input)
        
        guard let label = output.featureValue(for: "label")?.stringValue else {
            throw ClassifierTestError.missingLabel(transcript: transcript)
        }
        
        return label
    }
    
    private final class BundleToken {}
    
    private enum ClassifierTestError: LocalizedError, CustomStringConvertible {
        case hostBundleUnavailable(testBundlePath: String, attemptedHostBundlePath: String)
        case modelMissing(resource: String, bundlePath: String)
        case missingLabel(transcript: String)
        
        var errorDescription: String? {
            switch self {
            case .hostBundleUnavailable(let testBundlePath, let attemptedHostBundlePath):
                return "Could not resolve the host app bundle from test bundle '\(testBundlePath)'. Attempted host bundle path: '\(attemptedHostBundlePath)'."
            case .modelMissing(let resource, let bundlePath):
                return "Could not find '\(resource)' in bundle '\(bundlePath)'."
            case .missingLabel(let transcript):
                return "Classifier prediction for transcript '\(transcript)' did not include a 'label' output."
            }
        }
        
        var description: String {
            errorDescription ?? String(describing: self)
        }
    }
}
