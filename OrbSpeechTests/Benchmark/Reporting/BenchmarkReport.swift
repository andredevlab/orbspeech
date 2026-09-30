import Foundation

struct BenchmarkReport {
    let device: String
    let systemVersion: String
    let thermalStart: String
    let thermalEnd: String
    let totalDuration: Duration
    let runsPerCommand: Int
    let rows: [BenchmarkRow]
    
    func toLog() -> String {
        var lines = [
            "device=\(device)",
            "system_version=\(systemVersion)",
            "thermal_start=\(thermalStart)",
            "thermal_end=\(thermalEnd)",
            "total_duration_s=\(Self.format(totalDuration.seconds))",
            "runs_per_command=\(runsPerCommand)",
            "",
            "runs:"
        ]
        
        for row in rows {
            lines.append(
                "command=\(row.command) "
                + "run=\(row.run) "
                + "started_at_s=\(Self.format(row.startedAtSeconds)) "
                + "duration_ms=\(Self.format(row.durationMs)) "
                + "end_of_audio_to_acting_ms=\(Self.format(row.endOfAudioToActingMs)) "
                + "end_of_audio_to_terminal_ms=\(Self.format(row.endOfAudioToTerminalMs)) "
                + "interaction_to_terminal_ms=\(Self.format(row.interactionToTerminalMs)) "
                + "status=\(row.status) "
                + "thermal_state=\(row.thermalState)"
            )
        }
        
        return lines.joined(separator: "\n")
    }
    
    private static func format(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func format(_ value: Double?) -> String {
        value.map(format) ?? "n/a"
    }
}
