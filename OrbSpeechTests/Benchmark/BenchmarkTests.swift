import AVFoundation
import Darwin
import Foundation
import Factory
import Testing
import UIKit
import os
@testable import OrbSpeech

@Suite("Benchmark: end-to-end latency", .serialized)
@MainActor
struct BenchmarkTests {
    static let commands = [
        "move_left", "shift_right", "centre", "stop",
        "move", "move_top", "move_up", "move_down",
        "go_crimson", "colour_ocean"
    ]
    static let runsPerCommand = 10
    static let bundle = Bundle(for: BenchmarkBundleToken.self)
    
    static let sharedRecognizer = SpeechRecognizerFallbackOrchestrator()
    static let sharedSynthesizer = OrbSpeechSynthesizer()
    static let sharedResolver = CommandResolverFallbackOrchestrator()
    
    private static let signposter = OSSignposter(subsystem: "com.orb.speech",
                                                 category: .pointsOfInterest)
    
    @Test("Measures end-to-end command latency")
    func measureLatency() async throws {
#if targetEnvironment(simulator)
        throw BenchmarkError.prepareFailed("Benchmark must run on a physical iOS device, not the simulator.")
#endif
        
        let session = OrbSpeechSession.shared
        let originalViewModel = session.viewModel
        let microphone = BenchmarkMicrophoneFixtureRouter()
        Container.shared.microphoneCapturing.register { microphone }
        Container.shared.speechRecognizer.register { Self.sharedRecognizer }
        Container.shared.speechSynthesizer.register { Self.sharedSynthesizer }
        Container.shared.commandResolver.register { Self.sharedResolver }
        let viewModel = ContentViewModel()
        session.viewModel = viewModel
        let wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            session.viewModel = originalViewModel
            UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            Container.shared.reset()
        }
        if originalViewModel.isListening {
            await originalViewModel.interact()
        }
        
        let clock = ContinuousClock()
        let suiteStart = clock.now
        let thermalStart = ProcessInfo.processInfo.thermalState
        let preparationObservation = BenchmarkContentViewModelObservation(viewModel: viewModel)
        let preparationSnapshots = preparationObservation.start()
        await viewModel.prepareOnDeviceComponents()
        let preparedSnapshot = try await Self.waitForSnapshot(in: preparationSnapshots,
                                                              timeout: .seconds(5)) {
            $0.prepareButtonText == "All set"
        }
        #expect(preparedSnapshot.prepareButtonText == "All set")
        preparationObservation.stop()
        var rows: [BenchmarkRow] = []
        
        for run in 1...Self.runsPerCommand {
            for command in Self.commands.shuffled() {
                rows.append(try await Self.runOne(command: command,
                                                  run: run,
                                                  suiteStart: suiteStart,
                                                  viewModel: viewModel,
                                                  microphone: microphone))
                try await Task.sleep(for: .seconds(2))
            }
            if run < Self.runsPerCommand {
                if viewModel.isListening {
                    await viewModel.interact()
                }
                try await Task.sleep(for: .seconds(10))
            }
        }
        
        if viewModel.isListening {
            await viewModel.interact()
        }
        
        #expect(rows.count == Self.commands.count * Self.runsPerCommand)
        
        let thermalEnd = ProcessInfo.processInfo.thermalState
        let report = BenchmarkReport(device: Self.hardwareIdentifier(),
                                     systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                                     thermalStart: thermalStart.benchmarkName,
                                     thermalEnd: thermalEnd.benchmarkName,
                                     totalDuration: suiteStart.duration(to: clock.now),
                                     runsPerCommand: Self.runsPerCommand,
                                     rows: rows)
        
        print("=== BENCHMARK RESULTS BEGIN ===")
        print(report.toLog())
        print("=== BENCHMARK RESULTS END ===")
    }
    
    private static func runOne(command: String,
                               run: Int,
                               suiteStart: ContinuousClock.Instant,
                               viewModel: ContentViewModel,
                               microphone: BenchmarkMicrophoneFixtureRouter) async throws -> BenchmarkRow {
        guard let url = Self.audioURL(for: command) else {
            throw BenchmarkError.audioFileMissing(command)
        }
        let file = try AVAudioFile(forReading: url)
        let durationMs = Double(file.length) / file.processingFormat.sampleRate * 1000
        let clock = ContinuousClock()
        let runStart = clock.now
        let startedAtSeconds = suiteStart.duration(to: runStart).seconds
        
        let signpostState = signposter.beginInterval("command",
                                                     id: signposter.makeSignpostID(),
                                                     "\(command) run=\(run)")
        defer { signposter.endInterval("command", signpostState) }
        
        let audio = FileMicrophoneService(commandName: command,
                                          bundle: bundle,
                                          startsAutomatically: false)
        let uiObservation = BenchmarkContentViewModelObservation(viewModel: viewModel)
        let snapshots = uiObservation.start()
        
        do {
            try microphone.select(audio)
            print("[bench] command=\(command) run=\(run) started_at_s=\(startedAtSeconds) duration_ms=\(durationMs)")
            guard viewModel.canInteract else {
                throw BenchmarkError.prepareFailed("\(command): \(viewModel.statusText)")
            }
            
            if !viewModel.isListening {
                await viewModel.interact()
            }
            guard viewModel.isListening else {
                throw BenchmarkError.prepareFailed("\(command): \(viewModel.statusText)")
            }
            microphone.beginPlayback()
            let interactionStart = clock.now
            
            let observation = try await Self.waitForCommandObservation(in: snapshots,
                                                                       command: command,
                                                                       startedAt: interactionStart,
                                                                       logDiagnostics: run == 1 && command == commands.first)
            let endOfAudio = try await waitForEndOfAudio(command: command,
                                                         events: audio.events,
                                                         timeout: .seconds(durationMs / 1000 + 5))
            let row = BenchmarkRow(command: command,
                                   run: run,
                                   startedAtSeconds: startedAtSeconds,
                                   durationMs: durationMs,
                                   endOfAudioToActingMs: observation.firstActingAt.map { endOfAudio.duration(to: $0).milliseconds },
                                   endOfAudioToTerminalMs: endOfAudio.duration(to: observation.terminal.at).milliseconds,
                                   interactionToTerminalMs: interactionStart.duration(to: observation.terminal.at).milliseconds,
                                   status: observation.terminal.status,
                                   thermalState: ProcessInfo.processInfo.thermalState.benchmarkName)
            
            // Force a full stop of the listening session so the VoiceCommandCoordinator
            if viewModel.isListening {
                await viewModel.interact()
            }
            
            uiObservation.stop()
            return row
        } catch {
            if viewModel.isListening {
                await viewModel.interact()
            } else {
                microphone.stop()
            }
            uiObservation.stop()
            throw error
        }
    }
    
    private static func waitForEndOfAudio(command: String,
                                          events: AsyncStream<FileMicrophoneServiceEvent>,
                                          timeout: Duration) async throws -> ContinuousClock.Instant {
        try await withThrowingTaskGroup(of: ContinuousClock.Instant.self) { group in
            group.addTask {
                for await event in events {
                    if case .endOfAudio(let at) = event {
                        return at
                    }
                }
                throw BenchmarkError.timeout("Missing end-of-audio event for \(command)")
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BenchmarkError.timeout("Waiting for end of audio for \(command)")
            }
            defer { group.cancelAll() }
            guard let at = try await group.next() else {
                throw BenchmarkError.timeout("Missing end-of-audio event for \(command)")
            }
            return at
        }
    }
    
    private static func waitForCommandObservation(in snapshots: AsyncStream<BenchmarkContentViewModelObservation.Snapshot>,
                                                  command: String,
                                                  startedAt: ContinuousClock.Instant,
                                                  logDiagnostics: Bool,
                                                  timeout: Duration = .seconds(20)) async throws -> CommandRunObservation {
        try await withThrowingTaskGroup(of: CommandRunObservation.self) { group in
            group.addTask {
                var sawCommandActivity = false
                var firstActingAt: ContinuousClock.Instant?
                var lastLoggedStatus = ""
                
                for await snapshot in snapshots {
                    guard snapshot.at >= startedAt else { continue }
                    
                    if logDiagnostics, snapshot.statusText != lastLoggedStatus {
                        print("[bench] statusText=\(snapshot.statusText) orbState=\(snapshot.orbStateText)")
                        lastLoggedStatus = snapshot.statusText
                    }
                    
                    if firstActingAt == nil, Self.isActingSnapshot(snapshot) {
                        firstActingAt = snapshot.at
                    }
                    
                    if let terminal = Self.terminalStatus(from: snapshot) {
                        return CommandRunObservation(terminal: terminal,
                                                     firstActingAt: firstActingAt)
                    }
                    
                    if Self.isCommandActivity(snapshot) {
                        sawCommandActivity = true
                        continue
                    }
                    
                    if sawCommandActivity && Self.isListeningSnapshot(snapshot) {
                        let terminal = TerminalStatus(status: Self.fallbackTerminalStatus(for: command),
                                                      at: snapshot.at)
                        return CommandRunObservation(terminal: terminal,
                                                     firstActingAt: firstActingAt)
                    }
                }
                
                throw BenchmarkError.timeout("Missing terminal status for \(command)")
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BenchmarkError.timeout("Timed out waiting for terminal status for \(command)")
            }
            defer { group.cancelAll() }
            guard let observation = try await group.next() else {
                throw BenchmarkError.timeout("Missing terminal status for \(command)")
            }
            return observation
        }
    }
    
    private static func waitForSnapshot(in snapshots: AsyncStream<BenchmarkContentViewModelObservation.Snapshot>,
                                        timeout: Duration,
                                        where predicate: @escaping @Sendable (BenchmarkContentViewModelObservation.Snapshot) -> Bool) async throws -> BenchmarkContentViewModelObservation.Snapshot {
        try await withThrowingTaskGroup(of: BenchmarkContentViewModelObservation.Snapshot.self) { group in
            group.addTask {
                for await snapshot in snapshots where predicate(snapshot) {
                    return snapshot
                }
                throw BenchmarkError.timeout("Observation stream ended before the expected UI state")
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BenchmarkError.timeout("Timed out waiting for the expected UI state")
            }
            defer { group.cancelAll() }
            guard let snapshot = try await group.next() else {
                throw BenchmarkError.timeout("Missing UI state observation")
            }
            return snapshot
        }
    }
    
    private nonisolated static func terminalStatus(from snapshot: BenchmarkContentViewModelObservation.Snapshot) -> TerminalStatus? {
        let normalizedStatus = snapshot.statusText.lowercased()
        
        if normalizedStatus.contains("completed") {
            return TerminalStatus(status: "completed", at: snapshot.at)
        }
        if normalizedStatus.contains("unsupported") {
            return TerminalStatus(status: "unsupported", at: snapshot.at)
        }
        if normalizedStatus.contains("interrupted") {
            return TerminalStatus(status: "interrupted", at: snapshot.at)
        }
        if normalizedStatus.contains("cancelled") {
            return TerminalStatus(status: "cancelled", at: snapshot.at)
        }
        return nil
    }
    
    private nonisolated static func isListeningSnapshot(_ snapshot: BenchmarkContentViewModelObservation.Snapshot) -> Bool {
        snapshot.isListening && snapshot.statusText.lowercased().hasPrefix("listening - voice level:")
    }
    
    private nonisolated static func isActingSnapshot(_ snapshot: BenchmarkContentViewModelObservation.Snapshot) -> Bool {
        snapshot.statusText.lowercased() == "acting"
    }
    
    private nonisolated static func isCommandActivity(_ snapshot: BenchmarkContentViewModelObservation.Snapshot) -> Bool {
        !isListeningSnapshot(snapshot) && snapshot.statusText.lowercased() != "idle"
    }
    
    private nonisolated static func fallbackTerminalStatus(for command: String) -> String {
        if command == "stop" {
            return "cancelled"
        }
        
        let unsupportedCommands = ["move", "move_top", "move_up", "move_down", "go_crimson", "colour_ocean"]
        return unsupportedCommands.contains(command) ? "unsupported" : "completed"
    }
    
    private static func audioURL(for command: String) -> URL? {
        bundle.url(forResource: command, withExtension: "wav", subdirectory: "Audio")
        ?? bundle.url(forResource: command, withExtension: "wav")
    }
    
    private static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let bytes = withUnsafeBytes(of: &systemInfo.machine) { rawBuffer in
            rawBuffer.prefix { $0 != 0 }.map { UInt8($0) }
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}

private final class BenchmarkBundleToken {}
