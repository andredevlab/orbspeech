import Foundation
import Observation
@testable import OrbSpeech

@MainActor
final class BenchmarkContentViewModelObservation {
    struct Snapshot: Sendable {
        let at: ContinuousClock.Instant
        let statusText: String
        let orbStateText: String
        let isListening: Bool
        let prepareButtonText: String
    }

    private let viewModel: ContentViewModel
    private(set) var latest: Snapshot
    private var isObserving = false
    private var continuation: AsyncStream<Snapshot>.Continuation?

    init(viewModel: ContentViewModel) {
        self.viewModel = viewModel
        self.latest = Self.snapshot(for: viewModel)
    }

    func start() -> AsyncStream<Snapshot> {
        precondition(!isObserving, "Benchmark UI observation can only start once")

        isObserving = true
        let stream = AsyncStream<Snapshot>.makeStream(bufferingPolicy: .unbounded)
        continuation = stream.continuation
        continuation?.yield(latest)
        observeNextChange()
        return stream.stream
    }

    func stop() {
        isObserving = false
        continuation?.finish()
        continuation = nil
    }

    private func observeNextChange() {
        guard isObserving else { return }

        withObservationTracking {
            _ = viewModel.statusText
            _ = viewModel.orbState
            _ = viewModel.isListening
            _ = viewModel.onDeviceComponentsState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latest = Self.snapshot(for: self.viewModel)
                self.continuation?.yield(self.latest)
                print("[bench-ui] statusText=\(self.latest.statusText) "
                      + "orbState=\(self.latest.orbStateText) "
                      + "prepare=\(self.latest.prepareButtonText)")
                self.observeNextChange()
            }
        }
    }

    private static func snapshot(for viewModel: ContentViewModel) -> Snapshot {
        Snapshot(at: ContinuousClock().now,
                 statusText: viewModel.statusText,
                 orbStateText: String(describing: viewModel.orbState),
                 isListening: viewModel.isListening,
                 prepareButtonText: viewModel.canInteract ? "All set" : "Prepare Components")
    }
}
