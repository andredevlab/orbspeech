import SwiftUI

struct RumiOrbView: View {
    let background: Color
    let state: OrbState
    let visualState: OrbVisualState

    init(background: Color, state: OrbState, visualState: OrbVisualState = .default) {
        self.background = background
        self.state = state
        self.visualState = visualState
    }

    @Environment(\.displayScale) private var displayScale
    @State private var birth = Date.now
    @State private var thinkingBirth = Date.now

    var body: some View {
        let scale = displayScale
        let base = Color(red: visualState.baseRed,
                         green: visualState.baseGreen,
                         blue: visualState.baseBlue)
        let edge = Color(red: visualState.edgeRed,
                         green: visualState.edgeGreen,
                         blue: visualState.edgeBlue)

        TimelineView(.periodic(from: birth, by: 1.0 / 60.0)) { context in
            let time = birth.distance(to: context.date)
            let thinkingTime = thinkingBirth.distance(to: context.date)

            Rectangle()
                .fill(background)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        shaderArguments(size: proxy.size,
                                        time: time,
                                        thinkingTime: thinkingTime,
                                        scale: scale,
                                        base: base,
                                        edge: edge,
                                        visualState: visualState)
                    )
                }
                .accessibilityLabel(accessibilityLabel)
        }
        .onChange(of: state) { _, newState in
            if case .thinking = newState {
                thinkingBirth = Date.now
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
        }
    }

    nonisolated private func shaderArguments(size: CGSize,
                                             time: TimeInterval,
                                             thinkingTime: TimeInterval,
                                             scale: Double,
                                             base: Color,
                                             edge: Color,
                                             visualState: OrbVisualState) -> Shader {
        switch state {
        case .idle:
            ShaderLibrary.rumi_idle(
                .float2(size),
                .float(time),
                .float(scale),
                .color(base),
                .color(edge),
                .float2(visualState.xOffset, visualState.yOffset),
                .float(visualState.bounce)
            )
        case .listening(let level):
            ShaderLibrary.rumi_listening(
                .float2(size),
                .float(time),
                .float(scale),
                .color(base),
                .color(edge),
                .float2(visualState.xOffset, visualState.yOffset),
                .float(visualState.bounce),
                .float(min(max(level, 0.0), 1.0))
            )
        case .thinking:
            ShaderLibrary.rumi_thinking(
                .float2(size),
                .float(thinkingTime),
                .float(scale),
                .color(base),
                .color(edge),
                .float2(visualState.xOffset, visualState.yOffset),
                .float(visualState.bounce)
            )
        }
    }
}
