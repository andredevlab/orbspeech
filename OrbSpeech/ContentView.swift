import SwiftUI

struct ContentView: View {
    private let background = Color(red: 1,
                                   green: 1,
                                   blue: 1)

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            RumiOrbView(background: background,
                        state: .thinking)
                .ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                VStack(spacing: 18) {
                    Text("OrbSpeech")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)

                    Text("thinking")
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.black.opacity(0.46))
                        .padding(.horizontal, 36)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
