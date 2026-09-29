import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    private let background = Color(red: 1,
                                   green: 1,
                                   blue: 1)
    
    @State private var viewModel = ContentViewModel(microphoneCapturing: MicrophoneService(),
                                                    speechRecognizer: SpeechRecognizerFallbackOrchestrator(),
                                                    speechSynthesizer: OrbSpeechSynthesizer(),
                                                    commandResolver: CommandResolverFallbackOrchestrator())
    
    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            
            RumiOrbView(background: background,
                        state: viewModel.orbState,
                        visualState: viewModel.orbVisualState,
                        visualTransition: viewModel.orbVisualTransition)
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
                            await viewModel.prepareOnDeviceComponents()
                        }
                    } label: {
                        if viewModel.onDeviceComponentsState == .loading {
                            ProgressView()
                                .id(UUID())
                        } else {
                            Text(viewModel.onDeviceComponentsState == .success ? "All set" : "Prepare Components")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 240, height: 44)
                                .overlay {
                                    Capsule()
                                        .stroke(.black.opacity(0.16), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.onDeviceComponentsState == .success || viewModel.onDeviceComponentsState == .loading)
                    .opacity(viewModel.onDeviceComponentsState == .success ? 0.58 : 1)
                    
                    Button {
                        Task {
                            await viewModel.interact()
                        }
                    } label: {
                        Text(viewModel.isListening ? "Stop" : "Talk")
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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await viewModel.resumeListeningAfterForegroundIfNeeded()
                }
            case .background:
                viewModel.pauseListeningForBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
