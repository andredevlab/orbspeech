import Foundation

extension String {
    func normalizedText() -> String {
        normalizedText(skipping: [])
    }
    
    func normalizedText(skipping skippedTokens: Set<String>) -> String {
        normalizedTokens(skipping: skippedTokens).joined(separator: " ")
    }
    
    func normalizedTokens(skipping skippedTokens: Set<String> = []) -> [String] {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !skippedTokens.contains($0) }
    }
}
