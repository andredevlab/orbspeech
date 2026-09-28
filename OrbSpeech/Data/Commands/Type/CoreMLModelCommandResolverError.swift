import Foundation

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
