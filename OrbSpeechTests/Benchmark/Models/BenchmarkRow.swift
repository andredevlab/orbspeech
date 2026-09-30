struct BenchmarkRow {
    let command: String
    let run: Int
    let startedAtSeconds: Double
    let durationMs: Double
    let endOfAudioToActingMs: Double?
    let endOfAudioToTerminalMs: Double
    let interactionToTerminalMs: Double
    let status: String
    let thermalState: String
}
