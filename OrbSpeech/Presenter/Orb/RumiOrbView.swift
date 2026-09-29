import SwiftUI

struct RumiOrbView: View {
    let background: Color
    let state: OrbState
    let visualState: OrbVisualState
    let visualTransition: OrbVisualTransition?

    init(background: Color,
         state: OrbState,
         visualState: OrbVisualState = .default,
         visualTransition: OrbVisualTransition? = nil) {
        self.background = background
        self.state = state
        self.visualState = visualState
        self.visualTransition = visualTransition
    }

    @Environment(\.displayScale) private var displayScale
    @State private var birth = Date.now
    @State private var transitionBirth = Date.now

    var body: some View {
        let scale = displayScale
        TimelineView(.periodic(from: birth, by: 1.0 / 60.0)) { context in
            let time = birth.distance(to: context.date)
            let transitionTime = transitionBirth.distance(to: context.date)
            let currentTime = context.date.timeIntervalSinceReferenceDate
            let transitionElapsed = visualTransition.map { currentTime - $0.startTime } ?? 0

            Rectangle()
                .fill(background)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        shaderArguments(size: proxy.size,
                                        time: time,
                                        transitionTime: transitionTime,
                                        transitionElapsed: transitionElapsed,
                                        scale: scale,
                                        visualState: visualState,
                                        visualTransition: visualTransition)
                    )
                }
                .accessibilityLabel(accessibilityLabel)
        }
        .onChange(of: state) { _, newState in
            if case .thinking = newState {
                transitionBirth = Date.now
            }
            if case .settling = newState {
                transitionBirth = Date.now
            }
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            "Rumi idle orb"
        case .listening:
            "Rumi listening orb"
        case .thinking:
            "Rumi thinking orb"
        case .settling:
            "Rumi settling orb"
        case .speaking:
            "Rumi speaking orb"
        case .acting:
            "Rumi acting orb"
        }
    }

    nonisolated private func shaderArguments(size: CGSize,
                                             time: TimeInterval,
                                             transitionTime: TimeInterval,
                                             transitionElapsed: TimeInterval,
                                             scale: Double,
                                             visualState: OrbVisualState,
                                             visualTransition: OrbVisualTransition?) -> Shader {
        let transition = visualTransition ?? OrbVisualTransition(startState: visualState,
                                                                 targetState: visualState,
                                                                 startTime: 0,
                                                                 duration: 0)
        let start = transition.startState
        let target = transition.targetState
        
        switch state {
        case .idle:
            return ShaderLibrary.rumi_idle(
                .float2(size),
                .float(time),
                .float(scale),
                .color(start.baseColor),
                .color(start.edgeColor),
                .float2(start.xOffset, start.yOffset),
                .float(start.bounce),
                .color(target.baseColor),
                .color(target.edgeColor),
                .float2(target.xOffset, target.yOffset),
                .float(target.bounce),
                .float(transitionElapsed),
                .float(transition.duration),
                .float(transition.transientBounceAmplitude)
            )
        case .listening(let level):
            return ShaderLibrary.rumi_listening(
                .float2(size),
                .float(time),
                .float(scale),
                .color(start.baseColor),
                .color(start.edgeColor),
                .float2(start.xOffset, start.yOffset),
                .float(start.bounce),
                .color(target.baseColor),
                .color(target.edgeColor),
                .float2(target.xOffset, target.yOffset),
                .float(target.bounce),
                .float(transitionElapsed),
                .float(transition.duration),
                .float(transition.transientBounceAmplitude),
                .float(min(max(level, 0.0), 1.0))
            )
        case .speaking, .acting:
            return ShaderLibrary.rumi_listening(
                .float2(size),
                .float(time),
                .float(scale),
                .color(start.baseColor),
                .color(start.edgeColor),
                .float2(start.xOffset, start.yOffset),
                .float(start.bounce),
                .color(target.baseColor),
                .color(target.edgeColor),
                .float2(target.xOffset, target.yOffset),
                .float(target.bounce),
                .float(transitionElapsed),
                .float(transition.duration),
                .float(transition.transientBounceAmplitude),
                .float(0.0)
            )
        case .thinking:
            return ShaderLibrary.rumi_thinking(
                .float2(size),
                .float(transitionTime),
                .float(scale),
                .color(start.baseColor),
                .color(start.edgeColor),
                .float2(start.xOffset, start.yOffset),
                .float(start.bounce),
                .color(target.baseColor),
                .color(target.edgeColor),
                .float2(target.xOffset, target.yOffset),
                .float(target.bounce),
                .float(transitionElapsed),
                .float(transition.duration),
                .float(transition.transientBounceAmplitude)
            )
        case .settling:
            return ShaderLibrary.rumi_settling(
                .float2(size),
                .float(transitionTime),
                .float(scale),
                .color(start.baseColor),
                .color(start.edgeColor),
                .float2(start.xOffset, start.yOffset),
                .float(start.bounce),
                .color(target.baseColor),
                .color(target.edgeColor),
                .float2(target.xOffset, target.yOffset),
                .float(target.bounce),
                .float(transitionElapsed),
                .float(transition.duration),
                .float(transition.transientBounceAmplitude)
            )
        }
    }
}

private extension OrbVisualState {
    nonisolated var baseColor: Color {
        Color(red: baseRed, green: baseGreen, blue: baseBlue)
    }
    
    nonisolated var edgeColor: Color {
        Color(red: edgeRed, green: edgeGreen, blue: edgeBlue)
    }
}
