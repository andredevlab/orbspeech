enum FileMicrophoneServiceEvent: Sendable {
    case chunkEmitted(index: Int, at: ContinuousClock.Instant)
    case endOfAudio(at: ContinuousClock.Instant)
}
