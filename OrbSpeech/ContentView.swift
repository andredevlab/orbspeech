//
//  ContentView.swift
//  OrbSpeech
//
//  Created by Andre Lara on 17/09/26.
//

import SwiftUI

struct ContentView: View {
    private let background = Color(red: 0.1, green: 0.15, blue: 0.04)

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                RumiOrbView(background: background)
                    .frame(width: 190, height: 190)

                VStack(spacing: 18) {
                    Text("OrbSpeech")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("idle edge wave")
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.horizontal, 36)
                }

                Spacer()
            }
        }
    }
}

private struct RumiOrbView: View {
    let background: Color

    @Environment(\.displayScale) private var displayScale
    @State private var birth = Date.now

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
                        ShaderLibrary.rumi_idle(
                            .float2(proxy.size),
                            .float(time),
                            .float(scale),
                            .color(base),
                            .color(edge)
                        )
                    )
                }
                .accessibilityLabel("Rumi idle orb")
        }
    }
}

#Preview {
    ContentView()
}
