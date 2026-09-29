import Foundation

final class TranscriptSegmenter {
    private let skippedTokens: Set<String> = ["a", "an", "the", "to"]
    private var committedTokens: [String] = []
    private var pendingCommitTokensBySegment: [String: [String]] = [:]
    
    func reset() {
        committedTokens = []
        pendingCommitTokensBySegment = [:]
    }
    
    func segment(_ result: TranscriptionResult) -> TranscriptionResult {
        if !result.stableText.isEmpty {
            return TranscriptionResult(stableText: segment(result.stableText),
                                       volatileText: "")
        }
        
        return TranscriptionResult(stableText: "",
                                   volatileText: segment(result.volatileText))
    }
    
    func commit(_ transcript: String) {
        let normalizedText = transcript.normalizedText(skipping: skippedTokens)
        guard !normalizedText.isEmpty else { return }
        
        if let pendingTokens = pendingCommitTokensBySegment[normalizedText] {
            committedTokens = pendingTokens
        } else {
            committedTokens = transcript.normalizedTokens(skipping: skippedTokens)
        }
        
        pendingCommitTokensBySegment = [:]
    }
    
    private func segment(_ transcript: String) -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceTokens = trimmedTranscript.normalizedTokens(skipping: skippedTokens)
        guard !sourceTokens.isEmpty else { return "" }
        
        let segmentedText: String
        if committedTokens.isEmpty {
            segmentedText = trimmedTranscript
        } else if sourceTokens.starts(with: committedTokens) {
            let newTokens = sourceTokens.dropFirst(committedTokens.count)
            guard !newTokens.isEmpty else { return "" }
            segmentedText = newTokens.joined(separator: " ")
        } else {
            segmentedText = trimmedTranscript
        }
        
        let normalizedSegment = segmentedText.normalizedText(skipping: skippedTokens)
        if !normalizedSegment.isEmpty {
            pendingCommitTokensBySegment[normalizedSegment] = sourceTokens
        }
        return segmentedText
    }
}
