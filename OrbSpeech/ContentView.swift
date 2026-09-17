import SwiftUI

struct ContentView: View {
    private let background = Color(red: 1,
                                   green: 1,
                                   blue: 1)

    @State private var selectedState = SelectedOrbState.idle

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            RumiOrbView(background: background,
                        state: selectedState.orbState)
                .ignoresSafeArea()

            VStack(spacing: 44) {
                Spacer()

                VStack(spacing: 18) {
                    Text("OrbSpeech")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)

                    Picker("Orb state", selection: $selectedState) {
                        ForEach(SelectedOrbState.allCases) { state in
                            Text(state.title)
                                .tag(state)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 320)
                        .padding(.horizontal, 36)
                }
            }
        }
    }
}

private enum SelectedOrbState: String, CaseIterable, Identifiable {
    case idle
    case listening
    case thinking

    var id: Self { self }

    var title: String {
        rawValue
    }

    var orbState: OrbState {
        switch self {
        case .idle:
            .idle
        case .listening:
            .listening(0.65)
        case .thinking:
            .thinking
        }
    }
}

#Preview {
    ContentView()
}
