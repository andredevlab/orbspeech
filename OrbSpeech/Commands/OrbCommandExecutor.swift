import Foundation

@MainActor
final class OrbCommandExecutor {
    private var animationTask: Task<CommandOutcome, Never>?
    private var animationID: UUID?
    private var visualState: OrbVisualState
    private let update: (OrbVisualState) -> Void

    init(initialState: OrbVisualState, update: @escaping (OrbVisualState) -> Void) {
        visualState = initialState
        self.update = update
        update(initialState)
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
    }

    private func run(_ command: OrbCommand) async -> CommandOutcome {
        switch command.action {
        case "move":
            return await move(command)
        case "color":
            return await color(command)
        case "bounce":
            return await bounce(command)
        default:
            return CommandOutcome(id: command.id,
                                  status: "unsupported",
                                  detail: "The orb cannot perform action \"\(command.action)\".")
        }
    }

    private func move(_ command: OrbCommand) async -> CommandOutcome {
        guard let value = command.value?.lowercased() else {
            return CommandOutcome(id: command.id,
                                  status: "unsupported",
                                  detail: "Move needs a target like left, center, or right.")
        }

        let targetX: Double
        switch value {
        case "left":
            targetX = -110
        case "center", "middle":
            targetX = 0
        case "right":
            targetX = 110
        default:
            return CommandOutcome(id: command.id,
                                  status: "unsupported",
                                  detail: "Move target \"\(value)\" is not supported.")
        }

        let start = visualState
        var target = visualState
        target.xOffset = targetX
        target.yOffset = 0
        target.bounce = 0

        let completed = await animate(from: start, to: target, duration: 0.9) { progress in
            let settle = sin(progress * .pi) * 0.08
            return visualStateByMixing(start, target, progress).withBounce(settle)
        }

        return completed
            ? CommandOutcome(id: command.id, status: "completed", detail: "Moved \(value).")
            : CommandOutcome(id: command.id, status: "interrupted", detail: "Move was interrupted.")
    }

    private func color(_ command: OrbCommand) async -> CommandOutcome {
        guard let value = command.value?.lowercased() else {
            return CommandOutcome(id: command.id,
                                  status: "unsupported",
                                  detail: "Color needs a target like blue, red, or green.")
        }

        var target = visualState
        switch value {
        case "blue":
            target.baseRed = 0.02
            target.baseGreen = 0.07
            target.baseBlue = 0.24
            target.edgeRed = 0.20
            target.edgeGreen = 0.45
            target.edgeBlue = 1.0
        case "red":
            target.baseRed = 0.26
            target.baseGreen = 0.03
            target.baseBlue = 0.07
            target.edgeRed = 1.0
            target.edgeGreen = 0.20
            target.edgeBlue = 0.28
        case "green":
            target.baseRed = 0.03
            target.baseGreen = 0.20
            target.baseBlue = 0.10
            target.edgeRed = 0.22
            target.edgeGreen = 0.92
            target.edgeBlue = 0.50
        default:
            return CommandOutcome(id: command.id,
                                  status: "unsupported",
                                  detail: "Color \"\(value)\" is not supported.")
        }

        let completed = await animate(from: visualState, to: target, duration: 0.55)
        return completed
            ? CommandOutcome(id: command.id, status: "completed", detail: "Changed color to \(value).")
            : CommandOutcome(id: command.id, status: "interrupted", detail: "Color change was interrupted.")
    }

    private func bounce(_ command: OrbCommand) async -> CommandOutcome {
        let base = visualState.withBounce(0)
        let up = visualState.withBounce(1)

        let grew = await animate(from: base, to: up, duration: 0.18)
        guard grew else {
            return CommandOutcome(id: command.id, status: "interrupted", detail: "Bounce was interrupted.")
        }

        let settled = await animate(from: up, to: base, duration: 0.34)
        return settled
            ? CommandOutcome(id: command.id, status: "completed", detail: "Bounced.")
            : CommandOutcome(id: command.id, status: "interrupted", detail: "Bounce was interrupted.")
    }

    private func animate(from start: OrbVisualState,
                         to target: OrbVisualState,
                         duration: TimeInterval,
                         frame: ((Double) -> OrbVisualState)? = nil) async -> Bool {
        let frameCount = max(Int(duration * 60), 1)

        for index in 0...frameCount {
            if Task.isCancelled {
                return false
            }

            let linearProgress = Double(index) / Double(frameCount)
            let progress = easeInOut(linearProgress)
            let next = frame?(progress) ?? visualStateByMixing(start, target, progress)
            setVisualState(next)

            if index < frameCount {
                try? await Task.sleep(for: .seconds(duration / Double(frameCount)))
            }
        }

        setVisualState(target)
        return true
    }

    private func setVisualState(_ state: OrbVisualState) {
        visualState = state
        update(state)
    }

    private func easeInOut(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

private func visualStateByMixing(_ start: OrbVisualState,
                                 _ target: OrbVisualState,
                                 _ progress: Double) -> OrbVisualState {
    OrbVisualState(
        xOffset: mix(start.xOffset, target.xOffset, progress),
        yOffset: mix(start.yOffset, target.yOffset, progress),
        baseRed: mix(start.baseRed, target.baseRed, progress),
        baseGreen: mix(start.baseGreen, target.baseGreen, progress),
        baseBlue: mix(start.baseBlue, target.baseBlue, progress),
        edgeRed: mix(start.edgeRed, target.edgeRed, progress),
        edgeGreen: mix(start.edgeGreen, target.edgeGreen, progress),
        edgeBlue: mix(start.edgeBlue, target.edgeBlue, progress),
        bounce: mix(start.bounce, target.bounce, progress)
    )
}

private func mix(_ start: Double, _ target: Double, _ progress: Double) -> Double {
    start + (target - start) * progress
}

private extension OrbVisualState {
    func withBounce(_ value: Double) -> OrbVisualState {
        var copy = self
        copy.bounce = value
        return copy
    }
}
