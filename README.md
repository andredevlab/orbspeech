# OrbSpeech

OrbSpeech is a one-screen iOS prototype where a Metal-rendered orb listens to speech, resolves short spoken commands, speaks back through iOS speech synthesis, and animates in response.

The project focuses on a narrow end-to-end loop: microphone input, speech recognition, speech-to-command resolution, spoken feedback, interruption handling, cancellation, and shader-driven orb motion.

## Requirements

| Requirement | Version / Notes |
| --- | --- |
| Xcode | 26.3 or later |
| iOS SDK | 26.2 or later |
| Deployment target | iOS 26.0 |
| Scheme | `OrbSpeech` |
| Dependencies | Swift Package Manager resolves `Factory` and `FluidAudio` |

The app and test targets keep `IPHONEOS_DEPLOYMENT_TARGET` at `26.0` so Xcode can resolve iOS 26.2 simulator/device destinations while still building on newer SDKs.

## Running

Open `OrbSpeech.xcodeproj`, select the `OrbSpeech` scheme, and run on a physical iOS device for the real microphone experience.

The simulator is useful for building and running the automated tests, but it is not the target environment for manually speaking to the orb. Real microphone capture and the full speech loop should be validated on device.

In the app:

1. Tap `Prepare Components`.
2. Tap `Talk`.
3. Speak a short command.
4. The orb speaks a response and performs the command when supported.

## Supported Commands

The current command set is intentionally small:

- Move: `left`, `right`, `center`
- Color: `blue`, `red`, `green`
- Bounce
- Cancel
- Unknown or unsupported requests

Unsupported commands are handled explicitly. The orb says `Sorry, I can't do that yet.` instead of silently failing or pretending the command worked.

## Architecture

`ContentView` owns the UI only. It renders the Metal orb, status text, preparation button, and talk/stop button.

`ContentViewModel` owns the interaction flow and coordinates four protocol boundaries:

- `MicrophoneCapturing`
- `SpeechRecognizer`
- `SpeechSynthesizing`
- `CommandResolver`

The app uses `Factory` for dependency registration. The app runtime registers real microphone, speech, synthesis, and resolver components. UI tests replace those dependencies with deterministic fixtures through debug-only registration.

## Audio And Interruptions

`MicrophoneService` uses `AVAudioEngine` to capture audio once and publish two outputs:

- normalized microphone level for orb animation
- audio buffers for speech recognition

The same capture path feeds both the visual feedback and the transcription pipeline.

`MicrophoneService` owns `AVAudioSession` while listening. It uses `.playAndRecord`, `.voiceChat`, speaker output, and deactivates the session with `.notifyOthersOnDeactivation` when capture stops.

Audio interruptions are handled through `AVAudioSession.interruptionNotification`. When an interruption begins, capture stops, the current recognition stream is ended, command flow is reset, and the UI returns to an interrupted/ready state. OrbSpeech does not automatically resume after system audio interruptions.

Foreground/background transitions are handled separately. If the app goes to the background while listening, it pauses capture and resumes listening when the app becomes active again. The app intentionally does not keep listening in the background.

## Speech Recognition

`SpeechRecognizerFallbackOrchestrator` tries Apple Speech first. If that path is unavailable, it falls back to FluidAudio.

`FluidAudioSpeechRecognizer` uses FluidAudio's Parakeet TDT-CTC 110M Core ML ASR path instead of a hand-wired Qwen3-ASR pipeline. The goal is to use a streaming recognizer that is already packaged for Apple platforms and keep model loading, chunking, and inference behind one speech-recognition abstraction instead of adding a second custom inference stack.

FluidAudio is started with `.system` input so OrbSpeech keeps one microphone/audio-session owner. The app captures audio through `MicrophoneCapturing` and forwards buffers into the recognizer. That avoids two components competing to configure `AVAudioSession` or capture from the microphone at the same time. It also makes the recognizer testable with file-backed buffers: the FluidAudio integration test reads `move_left.wav`, converts it into `AVAudioPCMBuffer` chunks, and feeds the same streaming path used by live microphone capture.

This keeps the speech-recognition boundary independent from FoundationModels availability. Devices without Apple's on-device language model can still use the speech path and then fall back to the bundled Core ML command classifier.

## Command Resolution And Cancellation

Speech transcripts are segmented by `VoiceCommandCoordinator`. After one second without new words, the transcript is resolved into an `OrbCommand`.

Resolution currently uses:

1. `FoundationModelsCommandResolver`, when available
2. `CoreMLModelCommandResolver`, using the bundled `OrbCommandClassifier.mlmodel`
3. `NetworkingResolver`, a production boundary stub

`FoundationModelsCommandResolver` uses `SystemLanguageModel(useCase: .contentTagging)`, a constrained `GenerationSchema`, greedy sampling, temperature `0`, and a short token cap. The bundled Core ML classifier covers the same small command space and is also expected to decline unsupported requests.

Cancellation is treated as a real cancellation path, not as a normal resolver fallback. `CommandResolverFallbackOrchestrator` rethrows `CancellationError`, and `CommandFlowCoordinator` cancels pending command work, stops speech, clears queued commands, cancels animation, and returns the orb to a recoverable state.

Unknown results continue through the fallback chain and eventually become an explicit `.unknown` command. `.unknown` is handled by spoken refusal instead of a silent status update.

## Speech Output

`OrbSpeechSynthesizer` wraps `AVSpeechSynthesizer`.

The synthesizer chooses the best available `en-US` voice already installed on the device: premium first, then enhanced, then the default system voice. The app does not require an API key or a network speech service.

The ViewModel awaits speech before executing accepted commands, so the interaction order is:

1. understand command
2. speak acknowledgement, cancellation, or refusal
3. animate the orb when executable

While speaking, the orb stays visually calm. In the shader, `.speaking` renders like a quiet listening state so the spoken response remains the focus.

## Orb Rendering And Motion

`RumiOrbView` hosts the Metal shader. SwiftUI provides the frame clock through `TimelineView`, and Metal renders the orb per pixel.

The orb has explicit product states:

- `.idle`: waiting
- `.listening(level)`: reacting to microphone level
- `.thinking`: resolving the spoken command
- `.speaking`: saying a response out loud
- `.acting`: executing a command
- `.settling`: returning from a transition

Command execution emits an `OrbVisualTransition` containing start state, target state, start time, duration, and transient bounce. The shader receives those values as uniforms and interpolates movement, color, and bounce during rendering.

The command executor does not write observable animation state every frame. It emits transitions and waits for completion or cancellation. Per-pixel rendering and command-transition interpolation happen in Metal; SwiftUI still submits time and uniforms each frame.

## Networked Seam

OrbSpeech currently resolves commands on device. `NetworkingResolver` is kept as the production boundary where sentence understanding could move to a server later.

In this revision the network resolver is a local stub and fails fast. That keeps the normal command path responsive: FoundationModels and Core ML get the first chance to resolve a command, and unsupported input eventually becomes an explicit `.unknown` command.

A production live connection would need a turn-based protocol, for example:

1. `turn.start`: phone sends `turnId`, locale, current orb state, and device capabilities.
2. `audio.transcript.final`: phone sends the final transcript after local silence detection.
3. `command.resolve.request`: phone asks the server to resolve the transcript into an `OrbCommand`.
4. `command.resolve.result`: server returns an `OrbCommand` or an explicit `unknown`.
5. `assistant.speech.delta`: server streams response text if the spoken answer is server-authored.
6. `assistant.speech.done`: server marks the streamed answer complete.
7. `turn.complete`: phone reports that the local action finished or was skipped.

If the user interrupts halfway through a streamed answer, the phone sends `turn.cancel` with the `turnId`, the last received sequence number, and a reason such as `user_interrupted`. The server owes back `turn.cancelled` and must stop producing deltas for that turn.

The phone knows local facts the server cannot know immediately: whether the user tapped stop, whether iOS interrupted the microphone, whether the app lost audio focus, whether local speech playback was cancelled, and whether the local orb animation had already started.

If the connection drops mid-answer, the phone should stop trusting that turn, cancel local playback/animation, mark the turn as interrupted, and show a recoverable state. It should not keep acting on partial streamed intent unless the command had already been fully resolved and accepted locally.

For manual cancellation testing, the network stub can be slowed down locally by adding a temporary delay inside `NetworkingResolver.resolve`:

```swift
try await Task.sleep(for: .seconds(3))
```

With that local delay in place, say an unsupported command such as `I like barbecue`, then say `cancel` while the orb is still in the thinking state. This makes the network seam observable long enough to verify that pending resolver work is cancelled, command flow is reset, and the orb returns to a recoverable listening/idle state.

The delay is not part of normal app behavior. It is only a local verification hook for the cancellation path against a slow production-style seam.

## Tests

The project includes unit and UI coverage for behavior that can regress.

`OrbCommandClassifierTests` loads the bundled Core ML model and verifies supported commands plus refusal cases such as `move`, `move top`, `go crimson`, and `can you become the colour of the ocean`.

`OrbSpeechUITests` covers:

- the initial state before preparation
- a deterministic `move left` flow using the bundled `move_left.wav` audio fixture

The UI test launches with `ORB_UI_TEST_AUDIO_RESOURCE=move_left`, which loads `OrbSpeech/Resources/Audio/move_left.wav`. It also injects debug-only test doubles through launch environment values such as `ORB_UI_TEST_TRANSCRIPT`.

`FluidAudioRecognizerIntegrationTests` feeds the same `move_left.wav` fixture into the real `FluidAudioSpeechRecognizer` and verifies that the final normalized transcript contains `move left`.

Known issue: this is an integration test, not a fast unit test. `FluidAudioSpeechRecognizer.startStreaming` prepares the recognizer, and the first run may download/cache FluidAudio model assets, emit Model Catalog or UnifiedAssetFramework logs, and take noticeably longer than the classifier or UI fixture tests.

Cancellation against a slow network seam is currently verified manually with the temporary `NetworkingResolver` delay described above. A later test pass should turn that into an automated resolver/coordinator test instead of relying on a source-level debug delay.

## Build And Test

From Xcode:

1. Open `OrbSpeech.xcodeproj`.
2. In the toolbar scheme picker, select the `OrbSpeech` scheme.
3. In the run destination picker, select any installed iOS 26+ simulator for automated tests, such as `iPhone 17`.
4. Build with `Product > Build` or `Cmd-B`.
5. Run the test plan with `Product > Test` or `Cmd-U`.

The `OrbSpeech` scheme is connected to `OrbSpeech.xctestplan`, so testing from Xcode runs the classifier unit test, the FluidAudio integration test, and the UI test target. For manual microphone use, select a physical iOS device instead of the simulator.

`OrbSpeech.xctestplan` only enables parallel execution for the unit/integration test target. The UI test target intentionally runs serially because it drives one simulator app session through accessibility, launch environment values, fixture audio injection, and app lifecycle state. Parallel UI runners can compete for foreground focus, simulator automation, and shared app state, which would make this coverage slower to trust even if it looked faster on paper.

The test destination can be any installed iOS 26+ simulator. The automated tests are simulator-safe: the UI path injects a bundled audio fixture and test doubles instead of relying on live microphone input, and the FluidAudio integration test reads the bundled WAV fixture directly.

## Runtime Cost

Detailed runtime benchmarks are intentionally not included in this revision.

The main runtime costs are expected to come from:

- continuous microphone capture
- speech recognition
- command resolution through FoundationModels or Core ML
- speech synthesis
- continuous Metal rendering through `TimelineView`

A follow-up benchmark pass should measure heat, memory, energy impact, and frame behavior on one real device over a sustained session.

## Movement Choices

The motion reference contains more ideas than fit this scope. I kept the parts that make the interaction legible:

- idle motion should feel alive without pulling attention
- listening should react to real microphone input
- thinking should read differently from listening and acting
- acting should travel through a visible transition instead of snapping
- speaking should stay calm enough for the voice to be the focus

I left out deeper particle systems, large motion vocabularies, and more elaborate surfacing/settling variants. Those would be interesting polish, but the product loop depends first on audio, speech, command resolution, spoken feedback, cancellation, and Metal rendering all working together.

## What I Would Do With A Week

With a week, I would spend the extra time on depth rather than surface area:

- add sustained runtime benchmarks on a real device
- automate cancellation tests around a slow resolver
- add an interruption-focused UI or integration test
- capture command-resolution latency at each stage
- add confidence handling and better unknown-command thresholds
- make the network seam executable with a local fake server or streamed fixture
- broaden the motion language only after the command loop is measured

## What I Deliberately Did Not Build

I did not build a server, because the challenge only needs the seam and the local cancellation behavior to be visible.

I did not keep the microphone active in the background. That would require a different product/privacy contract, background audio mode, and more energy validation.

I did not expand the command set beyond movement, color, bounce, cancel, and unknown. A larger command space would need more classifier data, confidence handling, and more resolver tests.

I did not include sustained performance numbers in this revision. That belongs in the next benchmark-focused pass so the numbers can be measured and reported cleanly.

## AI Use

I used AI as a working pair, mostly for speed and comparison:

- researching Apple Speech, FoundationModels, Core ML, FluidAudio, MLX, llama.cpp, and Hugging Face options
- generating first passes of protocol boundaries and then simplifying them
- comparing fallback approaches for speech recognition and command resolution
- drafting README structure once the implementation was stable enough to explain

The places where AI was less useful were the concrete audio-session and timing details. It was too willing to treat cancellation and interruption abstractly, so those paths needed manual checking against how the app actually behaves.

The parts I checked by hand were:

- Xcode build and test behavior
- microphone capture logs
- speech recognizer fallback selection
- model availability and resolver fallback
- spoken refusal behavior
- UI state changes across listening, thinking, speaking, acting, and interruption

## One Thing Wrong In The Brief

The one-day framing is the weakest part of the brief. A prototype can be built in that time, but the brief also asks for Metal motion, real microphone input, on-device speech, model-backed command resolution, spoken output, cancellation, interruption recovery, a production network seam, tests, and honest runtime measurements.

The hard part is not sketching those pieces. The hard part is validating the edges: interruption timing, cancellation races, model refusal, thermal behavior, and sustained performance. Those are exactly the parts a lead should care about, and they benefit from more than one working day.
