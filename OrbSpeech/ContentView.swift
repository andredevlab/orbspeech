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
                        state: viewModel.orbState,
                        visualState: viewModel.orbVisualState)
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

                    HStack(spacing: 8) {
                        previewButton("left", action: "move", value: "left")
                        previewButton("middle", action: "move", value: "center")
                        previewButton("blue", action: "color", value: "blue")
                        previewButton("bounce", action: "bounce")
                        previewButton("?", action: "unknown")
                    }
                }
            }
        }
    }

    private var transcriptText: String {
        let stable = viewModel.stableTranscript
        let volatile = viewModel.volatileTranscript
        let transcriptLines = [stable, volatile]
            .filter { !$0.isEmpty }
            .map { "transcript: \($0)" }

        let commandLines = [viewModel.resolvedCommandText, viewModel.commandOutcomeText]
            .filter { !$0.isEmpty }

        let lines = transcriptLines + commandLines

        if lines.isEmpty {
            return "transcrição aparece aqui"
        }

        return lines.joined(separator: "\n")
    }

    private func previewButton(_ title: String,
                               action: String,
                               value: String? = nil) -> some View {
        Button {
            Task {
                await viewModel.executePreviewCommand(action: action, value: value)
            }
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.black)
                .frame(minWidth: 44, minHeight: 32)
                .padding(.horizontal, 6)
                .overlay {
                    Capsule()
                        .stroke(.black.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
