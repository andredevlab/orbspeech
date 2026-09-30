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

`ContentView` owns the UI and the scene lifecycle. It renders the Metal orb, status text, preparation button, and talk/stop button, and it forwards foreground/background transitions to the view model.

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

FluidAudio is configured to consume app-provided buffers through `streamAudio(buffer:)`. The intent is to keep a single microphone/audio-session owner: the app captures through `MicrophoneCapturing` and forwards buffers into the recognizer, so two components do not compete to configure `AVAudioSession` or capture from the microphone at the same time. This also makes the recognizer testable with file-backed buffers — the FluidAudio integration test reads `move_left.wav`, converts it into `AVAudioPCMBuffer` chunks, and feeds the same streaming path used by live microphone capture.

The exact `AVAudioSession` behaviour of `startStreaming(source: .system)` in FluidAudio should be verified on device. The app-facing integration point is `streamAudio(buffer:)`, which is what the integration test exercises.

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

This section describes the protocol that a production server would need. The seam is implemented as a local stub; the protocol is a design proposal, not shipped behaviour.

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

The test that covers a real failure mode is `OrbCommandClassifierTests`: the classifier can regress into returning movement commands for colour or out-of-domain input, which is worse than returning `unknown`. That test loads the bundled Core ML model and verifies supported commands plus refusal cases such as `move`, `move top`, `go crimson`, and `can you become the colour of the ocean`.

The other tests cover adjacent paths:

`OrbSpeechUITests` covers:

- the initial state before preparation
- a deterministic `move left` flow using the bundled `move_left.wav` audio fixture

The UI test launches with `ORB_UI_TEST_AUDIO_RESOURCE=move_left`, which loads `OrbSpeech/Resources/Audio/move_left.wav`. It also injects debug-only test doubles through launch environment values such as `ORB_UI_TEST_TRANSCRIPT`.

`FluidAudioRecognizerIntegrationTests` feeds the same `move_left.wav` fixture into the real `FluidAudioSpeechRecognizer` and verifies that the final normalized transcript contains `move left`.

Known issue: this is an integration test, not a fast unit test. `FluidAudioSpeechRecognizer.startStreaming` prepares the recognizer, and the first run may download/cache FluidAudio model assets, emit Model Catalog or UnifiedAssetFramework logs, and take noticeably longer than the classifier or UI fixture tests.

Cancellation against a slow network seam is currently verified manually with the temporary `NetworkingResolver` delay described above. A later test pass should turn that into an automated resolver/coordinator test instead of relying on a source-level debug delay.

Benchmark support is intentionally separate from the default test plan. It uses the test runner as an automation harness to replay audio fixtures, drive the real app flow, and print timing numbers from a physical device; it is not deterministic pass/fail coverage like the classifier or UI tests.

`OrbSpeechSession` exists for that benchmark path. The app root reads `OrbSpeechSession.shared.viewModel`, so the benchmark can install a benchmark-configured `ContentViewModel` and the visible UI observes the same instance being measured. Without that session boundary, the benchmark could mutate one view model while the on-screen `ContentView` kept rendering the original app-created model.

## Measured latency (one device)

The brief asked for "rough numbers from one device". This section reports them. The benchmark is a Swift Testing suite that injects pre-recorded `.wav` files through a `FileMicrophoneService` that mimics the real microphone at 16 kHz mono. It runs the full pipeline — ASR, resolver, command flow, synthesis, orb animation — without UI or manual input.

Setup: iPhone 11 (iPhone12,1), iOS 26.6.2, Xcode 26.3, release build. Thermal state: nominal at start and end of the run. 100 samples (10 commands × 10 runs), round-robin with shuffled order, 2 s between commands, 10 s between rounds. Median reported per command. Raw data: `benchmarks/orb_benchmark.csv`

| Command      | .wav duration | End of audio → terminal (median) | Interaction → terminal (median) | Status      |
|--------------|--------------:|---------------------------------:|--------------------------------:|-------------|
| move left    | 1.62 s        | 3704.1 ms                         | 5397.1 ms                       | completed   |
| shift right  | 2.05 s        | 3710.6 ms                         | 5850.5 ms                       | completed   |
| centre       | 4.97 s        | 1580.8 ms                         | 6768.7 ms                       | completed   |
| stop         | 2.88 s        | 740.0 ms                          | 3740.1 ms                       | cancelled   |
| move         | 1.69 s        | 3105.2 ms                         | 4866.2 ms                       | unsupported |
| move top     | 3.63 s        | 2327.7 ms                         | 6106.5 ms                       | unsupported |
| move up      | 1.96 s        | 3050.7 ms                         | 5090.6 ms                       | unsupported |
| move down    | 3.67 s        | 2269.2 ms                         | 6090.1 ms                       | unsupported |
| go crimson   | 2.22 s        | 3060.0 ms                         | 5377.7 ms                       | unsupported |
| colour ocean | 4.76 s        | 2683.7 ms                         | 7638.3 ms                       | unsupported |

### Reading the numbers

Two metrics are reported, and they answer different questions:

- end_of_audio → terminal measures how long the pipeline takes to finish after the .wav ends. It excludes playback time and is the metric comparable across commands of different durations.
- interaction → terminal measures from the moment playback starts to the terminal status. It includes .wav playback and reflects the latency a user would perceive with a command of that length.

What the numbers show:

- Accepted commands (move left, shift right, centre) resolve between 1.6 s and 3.7 s after the audio ends. The pipeline is dominated by the 1 s debounce in VoiceCommandCoordinator plus CoreML inference and the spoken acknowledgement.
- centre is the fastest accepted command (~1.6 s vs ~3.7 s) because "Center" stabilizes early in the ASR stream — the debounce fires before the .wav finishes playing.
- Refusals (move, move top, move up, move down, go crimson, colour ocean) resolve between 2.3 s and 3.1 s after the audio ends. They are faster than accepted commands because they skip the orb animation and go straight to a spoken refusal and settle.
- stop is the fastest (~0.7 s): cancelAll() speaks "Cancelled." and settles immediately, without an executor step.
- Variance across the 10 runs per command is under 100 ms. The pipeline is deterministic and the thermal state stayed nominal throughout the full 100-sample run.

### Is this good?

Short answer: the numbers are honest, they are dominated by one deliberate design choice, and they show two concrete opportunities for improvement.

The 1 s debounce accounts for 27–60 % of end_of_audio → terminal. VoiceCommandCoordinator waits 1 s of silence after the last transcript before resolving. That is intentional — it prevents resolving on a half-finished sentence — but it is the single largest fixed cost in the pipeline. For move left it is ~27 % of the 3.7 s; for centre it is ~63 % of the 1.6 s. Everything else — CoreML inference, command flow, spoken acknowledgement, orb animation — fits in the remaining 0.6–2.7 s.

Accepted commands land in the 1.6–3.7 s range after audio ends. That is the latency from the moment the user stops speaking to the moment the orb finishes its response. For a voice assistant that acknowledges out loud before acting, that is reasonable but not tight. A user would perceive it as responsive, not instantaneous. The original review measured ~8 s end-of-speech-to-motion on an earlier revision; this revision is in the 3.7–5.9 s range for the same metric, roughly halved.

stop at 0.7 s and refusals at 2.3–3.1 s are the right shape. Cancellation is fast because it skips the executor entirely. Refusals are faster than accepted commands because they skip the orb animation and go straight to a spoken "I can't do that yet." followed by settle. Both behaviours match the product intent: cancellation should feel immediate, refusal should feel definitive, accepted commands can take a beat because the orb is doing work.

What I would tighten first. The 1 s debounce is the obvious lever. It could drop to ~600 ms without hurting perceived accuracy on this command set. That alone would shave ~400 ms off every accepted command and refusal. The second lever is move top, move down, and colour ocean, which have longer .wav files and therefore longer interaction → terminal — but their end_of_audio → terminal is already comparable to shorter commands, so the extra time is playback, not pipeline.

Where the numbers are weak. Two caveats matter. First, Foundation Models never ran on the benchmark device, so the numbers reflect the CoreML fallback path only. On a device with Apple Intelligence, the Foundation Models path would run first and the numbers would likely shift. Second, prepareOnDeviceComponents() runs once per command and is excluded from both metrics — so the numbers measure the steady-state pipeline, not a cold start.

### What the numbers do not capture

- Foundation Models was unavailable on the benchmark device (Apple on-device language model unavailable: device not eligible). Every resolution came from the CoreML resolver. On a device with Apple Intelligence, the Foundation Models path would run first, and the numbers would likely differ.
- end_of_audio → acting is n/a for most commands. That column is only meaningful when the orb starts animating after the audio ends. For most commands the ASR stabilizes mid-audio and the animation begins while the .wav is still playing.
- No prepare measurement. prepareOnDeviceComponents() runs once per command and is excluded from both metrics. The recognizer's prepare() is a no-op after the first run, but the resolver prewarm() still runs and contributes to setup time.
- Single device, single environment. All numbers come from one iPhone 11 on iOS 26.6.2 at ambient temperature, with the thermal state recorded per sample. These are a rough indication, not a guarantee.

### How to reproduce

From Xcode:

1. Open `OrbSpeech.xcodeproj`.
2. In the toolbar scheme picker, select the `OrbSpeech` scheme.
3. In the run destination picker, select a physical iOS device — the benchmark rejects the simulator via `#if targetEnvironment(simulator)`.
4. Put the device in standby for 2–3 minutes so `ProcessInfo.thermalState` is nominal before starting.
5. Run only the benchmark test plan: `Product > Test` or `Cmd-U`, with `-only-testing:OrbSpeechTests/BenchmarkTests` selected.

From the command line:

```sh
xcodebuild test \
  -scheme OrbSpeech \
  -destination 'platform=iOS,name=<your device>' \
  -only-testing:OrbSpeechTests/BenchmarkTests
```

The test prints a CSV between `=== BENCHMARK RESULTS BEGIN ===` and `=== BENCHMARK RESULTS END ===`. Raw data from the run above is in `benchmarks/orb_benchmark.csv`.

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

- automate cancellation tests around a slow resolver (inserting a mock HTTPClient with delay to reproduce cancel command)
- add an interruption-focused UI or integration test
- capture command-resolution latency at each stage with Instruments
- add confidence handling and better unknown/known command thresholds
- make the network seam executable with a local fake server or streamed fixture (and show my "fullstack" skill with backend code)

## What I Deliberately Did Not Build

I did not build a server, because the challenge only needs the seam and the local cancellation behavior to be visible.

I did not keep the microphone active in the background. That would require a different product/privacy contract, background audio mode, and more energy validation.

I did not expand the command set beyond movement, color, bounce, cancel, and unknown. A larger command space would need more classifier data, confidence handling, and more resolver tests.

I did not include sustained performance numbers in this revision. That belongs in the next benchmark-focused pass so the numbers can be measured and reported cleanly.

## AI Use

I used AI as a working tool throughout the project, mostly for speed on the parts where comparison and recall matter more than original thinking: researching Apple Speech, FoundationModels, Core ML, FluidAudio, MLX, llama.cpp, and Hugging Face options; generating first passes of protocol boundaries; comparing fallback strategies for speech recognition and command resolution; and drafting README structure once the implementation was stable enough to explain.

That compression mattered. It let me invest time in the parts of the project that usually get cut when the clock is tight: cancellation that actually unwinds, interruption handling that recovers the session, spoken refusal instead of silent failure, and a benchmark that measures the pipeline instead of assuming it. Those are the parts where the prototype becomes a system.

The decisions, integrations, and anything that had to match device behaviour were mine. AI was not reliable for the concrete audio-session and timing details — it treated cancellation and interruption too abstractly — so those paths were validated against the app, not against a generated draft. The same applies to the build, the test suite, the fallback selection, the spoken refusal path, and the UI state transitions across listening, thinking, speaking, acting, and interruption.

## A Note On The Time Box

The brief asks for a lot inside a narrow time box: Metal motion, real microphone input, on-device speech, model-backed command resolution, spoken output, cancellation, interruption recovery, a production network seam, tests, and honest runtime measurements.

I prioritized the end-to-end loop over polish. The hard part is not sketching these pieces — it is validating the edges: interruption timing, cancellation races, model refusal, thermal behaviour, and sustained performance. Those are exactly the parts a lead should care about, and they benefit from more than one working day. The section "What I Would Do With A Week" lists what I would tackle next.