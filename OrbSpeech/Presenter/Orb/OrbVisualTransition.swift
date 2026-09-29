import Foundation

struct OrbVisualTransition: Equatable {
    let startState: OrbVisualState
    let targetState: OrbVisualState
    let startTime: TimeInterval
    let duration: TimeInterval
    let transientBounceAmplitude: Double
    
    nonisolated init(startState: OrbVisualState,
                     targetState: OrbVisualState,
                     startTime: TimeInterval,
                     duration: TimeInterval,
                     transientBounceAmplitude: Double = 0) {
        self.startState = startState
        self.targetState = targetState
        self.startTime = startTime
        self.duration = duration
        self.transientBounceAmplitude = transientBounceAmplitude
    }
    
    nonisolated func visualState(at time: TimeInterval) -> OrbVisualState {
        guard duration > 0 else { return targetState }
        
        let linearProgress = min(max((time - startTime) / duration, 0), 1)
        let progress = Self.easeInOut(linearProgress)
        var state = OrbVisualState.interpolating(from: startState,
                                                 to: targetState,
                                                 progress: progress)
        state.bounce += sin(progress * .pi) * transientBounceAmplitude
        return state
    }
    
    nonisolated private static func easeInOut(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

extension OrbVisualState {
    nonisolated static func interpolating(from start: OrbVisualState,
                                          to target: OrbVisualState,
                                          progress: Double) -> OrbVisualState {
        OrbVisualState(xOffset: mix(start.xOffset, target.xOffset, progress),
                       yOffset: mix(start.yOffset, target.yOffset, progress),
                       baseRed: mix(start.baseRed, target.baseRed, progress),
                       baseGreen: mix(start.baseGreen, target.baseGreen, progress),
                       baseBlue: mix(start.baseBlue, target.baseBlue, progress),
                       edgeRed: mix(start.edgeRed, target.edgeRed, progress),
                       edgeGreen: mix(start.edgeGreen, target.edgeGreen, progress),
                       edgeBlue: mix(start.edgeBlue, target.edgeBlue, progress),
                       bounce: mix(start.bounce, target.bounce, progress))
    }
    
    nonisolated func withBounce(_ value: Double) -> OrbVisualState {
        var copy = self
        copy.bounce = value
        return copy
    }
}

nonisolated private func mix(_ start: Double, _ target: Double, _ progress: Double) -> Double {
    start + (target - start) * progress
}
