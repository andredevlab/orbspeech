# OrbSpeech

OrbSpeech is a small iOS prototype where a Metal-rendered orb listens to the user, turns speech into text, resolves that text into an actionable command, responds out loud through speech synthesis, and animates the orb in response.

The goal of this implementation is to validate the end-to-end product interaction from the take-home challenge: microphone input, speech recognition, speech-to-command resolution, spoken feedback through `SpeechSynthesizing`, and orb animation. The scope was intentionally kept narrow so the full loop could be built and tested within the available time.

## Build Requirements

OrbSpeech is configured to build from a clean checkout with the following environment:

| Requirement | Version / Notes |
| --- | --- |
| Xcode | 26.3 or later |
| iOS SDK | 26.2 or later |
| Deployment target | iOS 26.0 |
| Scheme | `OrbSpeech` |
| Package dependencies | Resolved by Swift Package Manager on first build |

The app and test targets intentionally keep `IPHONEOS_DEPLOYMENT_TARGET` at `26.0` so the project can resolve destinations on the iOS 26.2 SDK while still building on newer Xcode releases.

## Challenge Mapping

The updated brief and email ask for a small one-screen product that spans graphics, audio, on-device AI, speech, a production networking boundary, cost analysis, and a short explanation of how the work was done.

This project focuses on proving the core on-device loop first:

| Ask | Current project status |
| --- | --- |
| Real microphone drives the orb | Implemented. `MicrophoneCapturing` uses `AVAudioEngine` and publishes both audio level and buffers. The level drives `.listening(level)` so the Metal orb reacts to the real signal. |
| Metal shaders, not SwiftUI-only animation | Implemented. `RumiOrbView` renders the orb through `RumiOrbMetal.metal`. SwiftUI still hosts the view and submits shader uniforms through `TimelineView`; the per-pixel orb rendering and command-transition interpolation happen in the shader. |
| On-device voice | Implemented. `SpeechSynthesizing` wraps `AVSpeechSynthesizer`; the orb speaks short local responses without a network call. |
| Spoken commands using a model | Implemented as a narrow validation slice. Speech becomes text, text goes through `CommandResolver`, and the result becomes an `OrbCommand`. The resolver pipeline supports FoundationModels when available and a bundled Core ML classifier fallback. |
| Command execution should feel like orb motion, not a snap | Implemented for the mapped actions. `OrbCommandExecutor` emits a start/target/time/duration transition for movement, color, and bounce; `RumiOrbMetal.metal` interpolates that transition. |
| Unknown commands should be handled honestly | Implemented. Unknown or unsupported commands go through `CommandFlowCoordinator`, which asks the orb to say that it cannot do that yet instead of pretending success. |
| User interruption should stop cleanly | Implemented for local capture and command flow. `MicrophoneService` observes `AVAudioSession.interruptionNotification`, stops capture on interruption start, and reports interruption end without auto-resuming after system interruptions. If the user backgrounds the app while listening, OrbSpeech pauses capture and resumes listening automatically when the app returns to foreground. |
| Networked seam | Partially implemented. A `NetworkingResolver` stub exists in the resolver chain and models the boundary where production command understanding could move off-device. The message protocol and failure behavior are described below. |
| Cost to run for long sessions | Not fully measured in-app. The current graphics path keeps per-pixel rendering and command-transition interpolation in Metal, while SwiftUI still submits time and uniforms once per `TimelineView` frame. Sustained heat/memory/battery measurement was left out to keep the implementation focused on the working loop. The measurement plan is documented below. |
| How I worked with AI | Documented below. AI helped accelerate implementation and alternatives research, but runtime behavior, audio-session choices, model availability, and shader behavior still needed manual checking. |

## Architecture

The final design separates the app into a SwiftUI view, a ViewModel, on-device audio/speech components, command resolution, and command execution.

### View

`ContentView` contains only UI and UX rules.

It renders:

- The Metal orb through `RumiOrbView`
- Status text from the ViewModel
- A button to prepare on-device components
- A button to start or stop interaction with the orb

The view does not know how audio capture, transcription, command resolution, or orb commands work. It only observes ViewModel state and calls ViewModel methods when the user taps a button.

### ViewModel

`ContentViewModel` owns the interaction flow.

It exposes state for the view to render:

- Button availability
- Status text
- Whether the app is listening
- The current `OrbState`
- The current `OrbVisualState`
- The active `OrbVisualTransition`, when a command animation is in flight

It also exposes the user-facing actions:

- `prepareOnDeviceComponents()`
- `interact()`

Internally, the ViewModel orchestrates the app components through protocols instead of concrete implementations:

- `MicrophoneCapturing`
- `SpeechRecognizer`
- `SpeechSynthesizing`
- `CommandResolver`

That keeps the ViewModel focused on product flow while allowing implementation details, fallbacks, and platform-specific behavior to live elsewhere.

## On-Device Components

The ViewModel initializes and coordinates three main on-device components.

### Microphone

`MicrophoneCapturing` captures audio once and publishes two outputs:

- `level`: a normalized voice level used to animate the orb while listening
- `buffer`: the raw audio buffer forwarded to the speech recognizer

The same audio capture path feeds both the visual feedback and transcription pipeline.

This component is also the right boundary for `AVAudioSession` ownership. When capture starts, `MicrophoneService` configures the shared audio session with `.playAndRecord`, uses `.voiceChat` mode, routes output to the speaker, and activates the session. In practice, that means OrbSpeech is asking the operating system for the microphone and audio session; if another app is playing audio, iOS may pause or duck that app depending on the active session policies.

When capture stops, the service removes the audio tap, stops the engine, clears its handlers, and deactivates the session with `.notifyOthersOnDeactivation`. That tells the operating system that OrbSpeech is done with the audio resource, allowing interrupted audio from another app to resume when iOS decides it can.

The interruption model belongs behind `MicrophoneCapturing` as well. If another app or system feature requests audio while OrbSpeech is using the microphone, iOS can interrupt the app's audio session and the capture pipeline must stop cleanly. `MicrophoneService` observes `AVAudioSession.interruptionNotification`, stops capture when an interruption begins, and notifies the ViewModel. The ViewModel then resets command flow, ends the current recognizer stream, and returns the UI to a state where the user can tap `interagir` again. When the interruption ends, the service reports whether iOS says the session may resume, but OrbSpeech does not restart listening automatically after system interruptions.

Foreground/background transitions are handled separately from audio-session interruptions. If the user sends OrbSpeech to the background while it is actively listening, the ViewModel pauses capture and remembers that listening was active. When the app becomes active again, it automatically rebuilds the capture pipeline and resumes listening. The app intentionally does not listen while it is in the background.

Keeping the microphone open in the background would require a different product and system contract: `UIBackgroundModes` with `audio`, a clear user-facing reason for background recording, careful privacy behavior, visible microphone usage, and more energy/performance validation. For this prototype, listening remains foreground-only.

### Speech Recognizer

`SpeechRecognizer` receives audio buffers and emits transcription results.

`SpeechRecognizerFallbackOrchestrator` decides which recognizer implementation should be used. Apple’s native speech stack is attempted first, and FluidAudio can be used as a fallback behind the same protocol.

This orchestration matters because the app should still work on devices that do not have Apple Intelligence or FoundationModels available, including older iPhones before the Apple Intelligence hardware cutoff. The speech-recognition path should not depend on those capabilities being present. Apple’s native speech recognizer is the first choice because it is integrated with the system, has low setup cost, and is the most natural default when on-device recognition is available for the current device and locale.

When that path is unavailable or not appropriate, the orchestrator falls back to FluidAudio. I chose FluidAudio for the prototype because it provides an app-owned on-device ASR path through CoreML, without requiring API keys or network transcription. It also hides a lot of the model plumbing that would otherwise be needed for a raw Hugging Face pipeline: model download, CoreML loading, sliding-window streaming, transcription updates, and local model cache. That made it a better fit for a two-day take-home implementation than wiring a lower-level Qwen3-ASR setup by hand.

One important integration detail is that FluidAudio is started with `stream.startStreaming(source: .system)` instead of `stream.startStreaming(source: .microphone)`. OrbSpeech already owns microphone capture through `MicrophoneCapturing` and `AVAudioSession`; letting FluidAudio open its own microphone path would create a second audio-capture owner competing for the same session. Using `.system` keeps FluidAudio in app-provided-buffer mode: `MicrophoneCapturing` captures the audio once, the ViewModel forwards each buffer to `SpeechRecognizer.stream(buffer:)`, and FluidAudio only performs ASR over those buffers.

The original research path considered Hugging Face models such as Qwen3-ASR CoreML/MLX variants. That direction is attractive for quality and multilingual support, but it has more moving parts: encoder and decoder assets, tokenizer handling, iOS 18+ `MLState`/KV-cache requirements for a full CoreML pipeline, memory constraints, and more device-specific validation. FluidAudio’s Parakeet TDT-CTC 110M CoreML path is smaller and more constrained, but it is much faster to validate end to end on device.

The ViewModel subscribes to transcription updates through `startStreaming`. Once the microphone starts sending buffers to `stream(buffer:)`, the recognizer publishes text updates back through that callback.

### Speech Synthesizer

`SpeechSynthesizing` is responsible for the orb’s spoken responses.

The ViewModel switches the orb to `.speaking` while synthesized speech is playing. In Metal, `.speaking` intentionally renders like `.listening(0)`: visually calm, centered, and not reacting to microphone level.

The synthesizer uses `AVSpeechSynthesizer` and picks the best available `en-US` voice already installed on the device: premium first, then enhanced, then the default system voice. The app does not download or require premium voices.

`speak(_:)` is exposed as an async method by wrapping `synthesizer.speak(utterance)` in a continuation. The continuation is resumed from `AVSpeechSynthesizerDelegate` when speech finishes or is cancelled. That means the ViewModel can await speech completion before moving the orb into `.acting`, so the orb executes the command only after it finishes talking.

## Speech-To-Command Flow

The ViewModel receives transcription updates from the speech recognizer and forwards them to `VoiceCommandCoordinator`. The coordinator segments accumulated ASR text and waits for one second without new words. That silence window is treated as the end of the user’s utterance.

After that one-second silence:

1. `VoiceCommandCoordinator` sends the final text to `CommandResolver`.
2. `CommandResolverFallbackOrchestrator` attempts to resolve the text into an `OrbCommand`.
3. The resolver decides what command the text means, but it does not directly mutate the orb.
4. `CommandFlowCoordinator` queues the resolved command and asks the ViewModel to speak accepted, cancelled, or unsupported responses.
5. `CommandFlowCoordinator` then asks `OrbCommandExecutor` to apply executable commands.

The command resolver is isolated behind a protocol so different strategies can be composed without changing the ViewModel. The current design supports fallback orchestration across on-device model resolution and the networking boundary.

Only a small set of commands is mapped right now. That was intentional: the priority was to validate the full speech-to-action loop quickly rather than spend the limited time expanding command coverage.

## Orb Command Execution

`OrbCommandExecutor` receives an `OrbCommand` and translates it into an `OrbVisualTransition`.

`OrbVisualState` contains the orb’s visual properties, such as:

- Position
- Color
- Bounce or other mapped effects

`OrbVisualTransition` contains the start state, target state, start time, duration, and any transient bounce used for the command. The executor is the component that knows the semantic target of a command, but it no longer calculates every animation frame itself.

The animation model avoids a separate command-side frame loop. Earlier versions used a `Task.sleep` loop on the `MainActor`, wrote observable visual state about 60 times per second, and ran that on top of a separate 60 Hz `TimelineView`, which meant command interpolation was CPU/MainActor work and was not display-synchronized.

The current implementation uses `TimelineView` as the single frame-time source for the orb. SwiftUI still evaluates the `TimelineView` closure each frame and submits uniforms to the shader. Metal renders the orb per pixel and interpolates command transitions from start/target/time/duration uniforms. The command executor emits the transition once, waits for completion or cancellation, and returns a `CommandOutcome` when the action finishes or is interrupted.

The executor currently implements only the few actions needed for rapid validation, such as movement, color, and bounce. More commands can be added by extending the resolver’s output space and mapping new actions into `OrbVisualState` transitions here.

## Movement Choices

The motion lab examples are intentionally broader than what fits in a short take-home. I kept the qualities that mattered most for validating the product loop:

- The orb should always feel alive, even when idle.
- Listening should react to real audio, not a fake timer.
- Thinking should feel different from listening and acting.
- Acting should move through a visible transition instead of snapping.
- Speaking should be calm enough that the voice feels like the focus.

I left out the deeper motion-lab experiments, complex particle systems, and additional transition verbs. Those would be interesting, but the challenge depends more on connecting audio, AI, speech, commands, and Metal into one coherent loop.

## Networked Seam

The app currently resolves commands locally. In production, I would move sentence understanding to a server only behind a clear turn-based protocol. The phone should still own the microphone, local visual state, local cancellation, and the final decision of what the user sees during a dropped connection.

One possible message order:

1. `turn.start`: phone sends `turnId`, locale, current orb state, and device capabilities.
2. `audio.transcript.final`: phone sends the final transcript after local silence detection.
3. `command.resolve.request`: phone asks the server to resolve the transcript into an `OrbCommand`.
4. `command.resolve.result`: server returns an `OrbCommand` or an explicit `unknown`.
5. `assistant.speech.delta`: if the server streams text for a spoken answer, it sends ordered chunks.
6. `assistant.speech.done`: server marks the streamed answer complete.
7. `turn.complete`: phone acknowledges that the local action finished or was skipped.

If the user interrupts halfway through a streamed answer, the phone sends `turn.cancel` with the `turnId`, the last received sequence number, and a reason such as `user_interrupted`. The server owes back `turn.cancelled` and must stop producing deltas for that turn. The phone knows things the server may not know yet: whether the user tapped stop, whether iOS interrupted the microphone, whether the app lost audio focus, and whether the local orb animation has already been cancelled.

If the connection drops mid-answer, the phone should stop trusting that turn, cancel local playback/animation, mark the turn as interrupted, and show a recoverable UI state. It should not keep acting on partial streamed intent unless the command had already been fully resolved and accepted locally.

In this prototype, `NetworkingResolver` is a local stub in the resolver chain. It waits briefly, fails, and lets the orchestrator fall back to on-device resolution. That proves the boundary exists, but the full streamed cancellation protocol above is documented rather than fully implemented.

## Orb States

The orb has explicit states for the product flow:

- `.idle`: waiting
- `.listening(level)`: listening and reacting to microphone level
- `.thinking`: processing or waiting
- `.settling`: returning from a thinking transition
- `.speaking`: speaking a response
- `.acting`: executing a command

The state controls the orb’s high-level behavior, while `OrbVisualState` controls its concrete visual details.

## Current Status

This is a complete end-to-end feature slice:

- Microphone capture
- Voice level animation
- Speech recognition
- One-second silence detection
- Speech-to-command resolution
- Spoken feedback
- Orb command execution
- Metal orb rendering

The implementation includes the core behavior needed to validate the challenge without expanding into a larger production architecture.

## Tests

The unit test target includes a Swift Testing regression test for the bundled Core ML command classifier. `OrbCommandClassifierTests` loads the compiled `OrbCommandClassifier.mlmodelc` from the host app bundle and verifies both supported commands and refusal cases.

The test intentionally covers examples that could break the product contract: valid movement and cancellation requests should still resolve to their expected labels, while ambiguous movement requests and unsupported color requests should resolve to `unknown`. That keeps the classifier from silently regressing into acting on commands such as `move`, `move top`, `go crimson`, or `can you become the colour of the ocean`.

I intentionally did not add detailed runtime instrumentation for model latency, memory, power, or token/model usage inside the app. That would be useful, but it would have taken time away from validating the primary interaction loop.

## Runtime Cost

I did not complete a proper sustained-session measurement pass. For a production submission, I would run the app on device for a longer session and record:

- Heat: Xcode thermal state and whether the device becomes noticeably warm.
- Memory: Xcode memory gauge and Instruments allocations over time, looking for growth during long listening sessions.
- Battery: Xcode energy report and Instruments Energy Log over a sustained listening and animation loop.
- Frame rate: Core Animation FPS and GPU counters while the orb is idle, listening, thinking, speaking, and acting.

The orb is rendered with Metal shaders, and command transitions are interpolated in the shader from start/target/time/duration uniforms. This is not a claim that the whole animation system is fully GPU-driven: SwiftUI's `TimelineView` still provides frame time from the main app layer and submits uniforms each frame. Command movement, color, and bounce are represented as transition uniforms rather than being calculated through per-frame observable state updates.

The main wins for holding 120fps for long sessions would come from keeping shader math bounded, reducing overdraw, limiting expensive noise layers, throttling state updates from the microphone, and avoiding unnecessary SwiftUI invalidations while audio is streaming.

The expensive parts of the app are not only the shader. The microphone is always active while listening, the speech recognizer may run CoreML inference, and the command resolver may use FoundationModels or CoreML. A two-hour session would need budget across all three: audio, ML, and graphics.

## Tradeoffs

The current implementation keeps presentation state in the ViewModel and moves the command-processing flow into dedicated coordinators. `VoiceCommandCoordinator` owns transcript segmentation, debounce, resolver tasks, and command submission. `CommandFlowCoordinator` owns command queueing, spoken command responses, execution, refusal, and cancellation.

The ViewModel still adapts coordinator events into UI state such as `.thinking`, `.speaking`, `.acting`, and `.listening`. That keeps UIKit/SwiftUI-facing state local while leaving command semantics outside the presentation layer.

I would also add:

- More robust cancellation and interruption handling
- Better command confidence reporting
- Runtime metrics for latency and resource usage
- A larger command model or larger on-device model strategy
- More test coverage around orchestration and command execution

## How I Worked With AI

I used AI as a working pair, not as a replacement for making the product decisions. The useful part was speed: I could ask it to explore options, generate first passes, compare APIs, and then quickly throw away what did not fit the actual behavior I wanted.

The main places where AI helped were:

- Researching the speech stack: Apple Speech, FoundationModels, CoreML, FluidAudio, MLX, llama.cpp, and Hugging Face options.
- Getting a first Metal orb on screen quickly, then simplifying it toward the smaller Rumi orb used here.
- Refactoring the prototype into protocol boundaries once the ViewModel started taking too much responsibility.
- Thinking through fallback paths, especially Apple-first speech recognition and FluidAudio as the older-device fallback.
- Drafting README sections once the architecture was stable enough to explain.

The places where AI was less helpful were just as important:

- It overcomplicated the orb state machine several times.
- It made some speech synthesis and microphone suggestions that created awkward timing or concurrency behavior.
- It treated some audio-session problems too abstractly; I had to bring it back to the concrete `AVAudioSession` ownership issue.
- It was too optimistic about what could be implemented cleanly in the time available.

The parts I checked by hand were the parts that matter for this prototype:

- Xcode builds after implementation changes.
- Runtime logs for microphone capture, resolver selection, model availability, and speech synthesis.
- Whether the orb actually moved through the intended user-facing states.
- Whether the app remained honest when a model or command was unavailable.
- Whether the final README described the project that actually exists, not the bigger version I would build with more time.

## Pushback

One thing I think is wrong in the brief is the expected time box. Polished Metal motion, live microphone input, on-device speech recognition, model-driven command understanding, spoken output, a production networking seam, cancellation, and sustained performance measurement are not naturally a one-day exercise.

If I were shaping this as a lead-level or production-quality challenge, I would make it closer to four focused working days. That would leave room not only to make the loop work, but to organize the code properly, validate cancellation paths, measure performance honestly, and clean up the edges.

For this submission, I worked on it in separate blocks adding up to roughly 16 hours. I am not as proud of the code organization as I would want to be for production, but given the time available I think the prototype lands the important part: the orb listens to real audio, understands a small set of spoken commands through model-backed components, speaks back, and animates through Metal.

## Why This Shape

The challenge asks for more than transcription or parsing. The important part is that spoken intent becomes a command the orb can act on, and that the action feels native to the orb’s motion language.

This architecture keeps that split clear:

- Speech components produce text
- Command resolver converts text into intent
- Command executor converts intent into orb behavior
- Metal renders the orb
- The ViewModel coordinates the product flow
- The view stays declarative and UI-only

Ultimately, these choices were made to preserve a good user experience: the orb should listen, speak, move, and recover from interruptions in a way that feels intentional instead of stitched together.
