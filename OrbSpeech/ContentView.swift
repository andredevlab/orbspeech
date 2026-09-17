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
                ScrollView {
                    Text(transcriptText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.62))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)

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
                            await viewModel.prepareAppleNative()
                        }
                    } label: {
                        Text(viewModel.isAppleNativeReady ? "Apple nativo pronto" : "preparar Apple nativo")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.black)
                            .frame(width: 240, height: 44)
                            .overlay {
                                Capsule()
                                    .stroke(.black.opacity(0.16), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isAppleNativeReady || viewModel.isPreparing)
                    .opacity(viewModel.isAppleNativeReady ? 0.58 : 1)

                    Button {
                        Task {
                            await viewModel.interact()
                        }
                    } label: {
                        Text(viewModel.isListening ? "parar" : "interagir")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(width: 148, height: 44)
                            .background(viewModel.canInteract || viewModel.isListening ? .black : .black.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canInteract && !viewModel.isListening)
                }
            }
        }
    }

    private var transcriptText: String {
        let stable = viewModel.stableTranscript
        let volatile = viewModel.volatileTranscript

        if stable.isEmpty && volatile.isEmpty {
            return "transcrição aparece aqui"
        }

        return [stable, volatile]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

#Preview {
    ContentView()
}
