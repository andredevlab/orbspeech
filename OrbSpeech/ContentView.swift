//
//  ContentView.swift
//  OrbSpeech
//
//  Created by Andre Lara on 17/09/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.045, blue: 0.04)
                .ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                DuetMetalOrb()
                    .frame(width: 190, height: 190)

                VStack(spacing: 18) {
                    Text("OrbSpeech")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("two lights orbiting each other inside the conversation")
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

private struct DuetMetalOrb: View {
    @Environment(\.displayScale) private var displayScale
    @State private var birth = Date.now

    var body: some View {
        let scale = displayScale
        let ink = Color(red: 0.05, green: 0.045, blue: 0.04)

        TimelineView(.periodic(from: birth, by: 0.40 / 60.0)) { context in
            let time = birth.distance(to: context.date)

            Rectangle()
                .fill(ink)
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.mh_duet(
                            .float2(proxy.size),
                            .float(time),
                            .float(scale),
                            .color(ink),
                            .color(Color(red: 0.43, green: 0.39, blue: 0.91)),
                            .float(0.0),
                            .float(1.0),
                            .float(0.82),
                            .float(0.78),
                            .float(1.0),
                            .float(0.5),
                            .float(0.5),
                            .float(0.5),
                            .float(0.6),
                            .float(0.0),
                            .float(2.0),
                            .float(2.2),
                            .float(0.0),
                            .float(0.32),
                            .float2(CGPoint.zero),
                            .color(Color(red: 0.12, green: 0.48, blue: 1.0))
                        )
                    )
                }
                .clipShape(Circle())
                .accessibilityLabel("Duet orb")
        }
    }
}

#Preview {
    ContentView()
}
