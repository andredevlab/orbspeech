import SwiftUI

struct RumiOrbView: View {
    let background: Color
    let state: OrbState

    @Environment(\.displayScale) private var displayScale
    @State private var birth = Date.now
    @State private var thinkingBirth = Date.now

    var body: some View {
        let scale = displayScale
        let base = Color(red: 0.02, green: 0.07, blue: 0.24)
        let edge = Color(red: 0.20, green: 0.45, blue: 1.0)

        TimelineView(.periodic(from: birth, by: 1.0 / 60.0)) { context in
            let time = birth.distance(to: context.date)

            Rectangle()
                .fill(background)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        shaderArguments(size: proxy.size,
                                        time: time,
                                        thinkingTime: thinkingBirth.distance(to: context.date),
                                        scale: scale,
                                        base: base,
                                        edge: edge)
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
                                             edge: Color) -> Shader {
        switch state {
        case .idle:
            ShaderLibrary.rumi_idle(
                .float2(size),
                .float(time),
                .float(scale),
                .color(base),
                .color(edge)
            )
        case .listening(let frequency):
            ShaderLibrary.rumi_listening(
                .float2(size),
                .float(time),
                .float(scale),
                .color(base),
                .color(edge),
                .float(min(max(frequency, 0.0), 1.0))
            )
        case .thinking:
            ShaderLibrary.rumi_thinking(
                .float2(size),
                .float(thinkingTime),
                .float(scale),
                .color(base),
                .color(edge)
            )
        }
    }
}
