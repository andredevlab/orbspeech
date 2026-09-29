import Foundation

@MainActor
final class OrbCommandExecutor {
    private var animationTask: Task<CommandOutcome, Never>?
    private var animationID: UUID?
    private var visualState: OrbVisualState
    private var activeTransition: OrbVisualTransition?
    private let update: (OrbVisualState, OrbVisualTransition?) -> Void
    
    init(initialState: OrbVisualState, update: @escaping (OrbVisualState, OrbVisualTransition?) -> Void) {
        visualState = initialState
        self.update = update
        update(initialState, nil)
    }
    
    func execute(_ command: OrbCommand) async -> CommandOutcome {
        animationTask?.cancel()
        
        let id = UUID()
        animationID = id
        let task = Task { @MainActor in
            await run(command)
        }
        animationTask = task
        
        let outcome = await task.value
        if animationID == id {
            animationTask = nil
            animationID = nil
        }
        return outcome
    }
    
    func cancel() {
        animationTask?.cancel()
        animationTask = nil
        animationID = nil
        
        // Cancellation policy: freeze in place. The shader owns the normal
        // per-frame interpolation, but cancellation materializes the current
        // interpolated value once so the residual visual state is defined.
        if let activeTransition {
            setVisualPresentation(state: activeTransition.visualState(at: Date.now.timeIntervalSinceReferenceDate),
                                  transition: nil)
        }
    }
    
    private func run(_ command: OrbCommand) async -> CommandOutcome {
        switch command.action {
        case .move:
            return await move(command)
        case .color:
            return await color(command)
        case .bounce:
            return await bounce(command)
        case .cancel, .unknown:
            return CommandOutcome(id: command.id,
                                  status: .unsupported,
                                  detail: "The orb cannot perform action \"\(command.action.rawValue)\".")
        }
    }
    
    // MARK: Commands
    
    private func move(_ command: OrbCommand) async -> CommandOutcome {
        guard let targetValue = command.value?.lowercased() else {
            return CommandOutcome(id: command.id,
                                  status: .unsupported,
                                  detail: "Move needs a target like left, center, or right.")
        }
        
        guard let moveTarget = OrbMoveTarget(targetValue) else {
            return CommandOutcome(id: command.id,
                                  status: .unsupported,
                                  detail: "Move target \"\(targetValue)\" is not supported.")
        }
        
        let start = visualState
        var target = visualState
        target.xOffset = moveTarget.xOffset
        target.yOffset = 0
        target.bounce = 0
        
        let completed = await animate(from: start,
                                      to: target,
                                      duration: 0.9,
                                      transientBounceAmplitude: 0.08)
        
        return completed
        ? CommandOutcome(id: command.id, status: .completed, detail: "Moved \(moveTarget.spokenValue).")
        : CommandOutcome(id: command.id, status: .interrupted, detail: "Move was interrupted.")
    }
    
    private func color(_ command: OrbCommand) async -> CommandOutcome {
        guard let targetValue = command.value?.lowercased() else {
            return CommandOutcome(id: command.id,
                                  status: .unsupported,
                                  detail: "Color needs a target like blue, red, or green.")
        }
        
        guard let colorTarget = OrbColorTarget(targetValue) else {
            return CommandOutcome(id: command.id,
                                  status: .unsupported,
                                  detail: "Color \"\(targetValue)\" is not supported.")
        }
        
        let target = colorTarget.applying(to: visualState)
        let completed = await animate(from: visualState,
                                      to: target,
                                      duration: 0.55)
        return completed
        ? CommandOutcome(id: command.id,
                         status: .completed,
                         detail: "Changed color to \(colorTarget.rawValue).")
        : CommandOutcome(id: command.id,
                         status: .interrupted,
                         detail: "Color change was interrupted.")
    }
    
    private func bounce(_ command: OrbCommand) async -> CommandOutcome {
        let base = visualState.withBounce(0)
        let up = visualState.withBounce(1)
        
        let grew = await animate(from: base, to: up, duration: 0.18)
        guard grew else {
            return CommandOutcome(id: command.id,
                                  status: .interrupted,
                                  detail: "Bounce was interrupted.")
        }
        
        let settled = await animate(from: up, to: base, duration: 0.34)
        return settled
        ? CommandOutcome(id: command.id,
                         status: .completed,
                         detail: "Bounced.")
        : CommandOutcome(id: command.id,
                         status: .interrupted,
                         detail: "Bounce was interrupted.")
    }
    
    // MARK: Animation core
    
    /// Emits one transition and waits for its duration. `RumiOrbView`'s
    /// `TimelineView` is the only frame clock; Metal interpolates the
    /// transition per frame from the emitted uniforms.
    private func animate(from start: OrbVisualState,
                         to target: OrbVisualState,
                         duration: TimeInterval,
                         transientBounceAmplitude: Double = 0) async -> Bool {
        let transition = OrbVisualTransition(startState: start,
                                             targetState: target,
                                             startTime: Date.now.timeIntervalSinceReferenceDate,
                                             duration: duration,
                                             transientBounceAmplitude: transientBounceAmplitude)
        setVisualPresentation(state: start, transition: transition)
        
        do {
            let nanoseconds = UInt64(max(duration, 0) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            setVisualPresentation(state: transition.visualState(at: Date.now.timeIntervalSinceReferenceDate),
                                  transition: nil)
            return false
        }
        
        guard !Task.isCancelled else {
            setVisualPresentation(state: transition.visualState(at: Date.now.timeIntervalSinceReferenceDate),
                                  transition: nil)
            return false
        }
        
        setVisualPresentation(state: target, transition: nil)
        return true
    }
    
    private func setVisualPresentation(state: OrbVisualState,
                                       transition: OrbVisualTransition?) {
        visualState = state
        activeTransition = transition
        update(state, transition)
    }
}

// MARK: - Target mappings

private extension OrbMoveTarget {
    var xOffset: Double {
        switch self {
        case .left:
            return -110
        case .center, .middle:
            return 0
        case .right:
            return 110
        }
    }
}

private extension OrbColorTarget {
    func applying(to visualState: OrbVisualState) -> OrbVisualState {
        var target = visualState
        switch self {
        case .blue:
            target.baseRed = 0.02
            target.baseGreen = 0.07
            target.baseBlue = 0.24
            target.edgeRed = 0.20
            target.edgeGreen = 0.45
            target.edgeBlue = 1.0
        case .red:
            target.baseRed = 0.26
            target.baseGreen = 0.03
            target.baseBlue = 0.07
            target.edgeRed = 1.0
            target.edgeGreen = 0.20
            target.edgeBlue = 0.28
        case .green:
            target.baseRed = 0.03
            target.baseGreen = 0.20
            target.baseBlue = 0.10
            target.edgeRed = 0.22
            target.edgeGreen = 0.92
            target.edgeBlue = 0.50
        }
        return target
    }
}
