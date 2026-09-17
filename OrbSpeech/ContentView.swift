import SwiftUI

struct ContentView: View {
    private let background = Color(red: 1,
                                   green: 1,
                                   blue: 1)

    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            RumiOrbView(background: background,
                        state: viewModel.orbState)
                .ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                VStack(spacing: 18) {
                    Text("OrbSpeech")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)

                    Text(viewModel.statusText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.46))

                    Button {
                        Task {
                            await viewModel.interact()
                        }
                    } label: {
                        Text(viewModel.isListening ? "parar" : "interagir")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 148, height: 44)
                            .background(.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
