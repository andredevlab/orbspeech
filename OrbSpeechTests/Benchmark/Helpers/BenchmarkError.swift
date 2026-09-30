import Foundation

enum BenchmarkError: Error, LocalizedError, Sendable {
    case audioFileMissing(String)
    case prepareFailed(String)
    case timeout(String)

    var errorDescription: String? {
        switch self {
        case .audioFileMissing(let name):
            return "Benchmark audio file missing: \(name)"
        case .prepareFailed(let reason):
            return "Benchmark preparation failed: \(reason)"
        case .timeout(let reason):
            return "Benchmark timed out: \(reason)"
        }
    }
}
