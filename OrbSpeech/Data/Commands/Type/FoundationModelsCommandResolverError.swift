import Foundation
import FoundationModels

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
