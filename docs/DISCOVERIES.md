# Discoveries

Empirical findings from working with on-device Apple Foundation Models
(`SystemLanguageModel`) in this project. This file records what was tried,
what worked, what did not, and where the boundaries are. It is not a
changelog. Update it when new empirical evidence is gathered.

## Scope

Findings were gathered from `SystemLanguageModel(useCase: .contentTagging)`
and `SystemLanguageModel.default` on macOS with Apple Intelligence enabled.
The current `FoundationModelsCommandResolver` uses `SystemLanguageModel.default`.

## System requirements

The FoundationModels framework requires macOS 26.0+ (Golden Gate). The
contentTagging use case runs on the base on-device model, available on
M1+ with 8GB. Advanced on-device models (M3+/12GB) are not required for
this use case. The guardrail classifier is independent of the model and
does not improve with hardware.

## Framework behavior

- Instructions define persona and constraints; prompts are user input.
  Instructions take priority over prompts.
- Context window: 4096 tokens per session. Everything counts:
  instructions, prompts, schema, tool definitions, responses.
- The model is stateless: every call starts fresh.
- `contentTagging` is specialized for extracting tags (topics, emotions,
  actions, objects) and always responds with tags. It is not designed
  for classification with negation rules.
- `default` is a general-purpose model, better suited for instruction
  following and closed-grammar classification.

## Guardrail handling

- Guardrail violations are a separate classifier, not part of the model.
- Apple recommends: rephrase the prompt, use a role in instructions,
  consider permissive guardrail mode.
- False positives are documented. Apple forums show `Tailwind` and
  `JFK` triggering guardrails in an aviation app.
- Handle `guardrailViolation` as a first-class error, not a generic one.

## Next step

The `contentTagging` use case is optimized for tagging, not for
classification with negation. The observed failures (collapse to nearest
valid label, inability to follow "if not X, then Y") were consistent with
the model's specialization.

The next experiment was:

1. Switch to `SystemLanguageModel.default`.
2. Keep the same schema (two fields: target, command).
3. Keep the same instructions (concise, example-driven).
4. Run the integration suite and record the result.

`.default` improved some instruction-following behavior, but the later
characterization tests still show unsupported-boundary collapses.

## Experiment: classifying orb voice commands with Foundation Models

### Goal

Classify short English speech transcripts into a closed set of orb
command labels:

- `color_blue`, `color_red`, `color_green`
- `unsupported_color`
- `move_left`, `move_center`, `move_right`
- `bounce`
- `cancel`
- `unknown_request`

### Approach

A single-property `GenerationSchema` constrained the output to the label
enum via `guides: [.anyOf(...)]`. The system instructions described each
label with examples. `GenerationOptions` used greedy sampling,
`temperature: 0`, `maximumResponseTokens: 40`.

### Baseline results (first prompt)

| Transcript          | Expected          | Observed                     |
|---------------------|-------------------|------------------------------|
| `move left`         | `move_left`       | `move_left` ✅               |
| `shift right`       | `move_right`      | `move_right` ✅              |
| `go left`           | `move_left`       | `move_left` ✅               |
| `go right`          | `move_right`      | `move_right` ✅              |
| `centre yourself`   | `move_center`     | `move_center` ✅             |
| `turn blue`         | `color_blue`      | `color_blue` ✅              |
| `go blue`           | `color_blue`      | `color_blue` ✅              |
| `go green`          | `color_green`     | `color_green` ✅             |
| `turn red`          | `color_red`       | `color_red` ✅               |
| `give me a bounce`  | `bounce`          | `bounce` ✅                  |
| `stop`              | `cancel`          | `cancel` ✅                  |
| `can you become the color of the ocean` | `color_blue` | `color_blue` ✅ |
| `move somewhere`    | any move          | any move ✅                  |
| `go to another spot`| any move          | any move ✅                  |
| `go crimson`        | `unknown_request` | `move_center` ❌             |
| `go yellow`         | `unknown_request` | `move_center` ❌             |
| `turn purple`       | `unknown_request` | `color_blue` ❌              |
| `make a square`     | `unknown_request` | `move_center` ❌             |

12/18 passed. The model correctly generalizes paraphrases ("ocean" →
blue, "shift" → move), which is the capability that justified using an
LLM in the first place.

### Second attempt (prompt + schema revision)

Changes applied:

1. Removed conflicting rules (`unknown_request` vs `unsupported_color`).
2. Replaced meta-rules ("ambiguous verbs do not decide") with examples.
3. Simplified per-call prompt to just the transcript.
4. Added a `target` field before `command` in the schema to anchor the
   model on the literal target word.

### Second attempt results

| Transcript                              | Expected          | Observed                   |
| :-------------------------------------- | :---------------- | :------------------------- |
| `go crimson`                            | `unknown_request` | `move_left` ❌             |
| `go yellow`                             | `unknown_request` | `move_left` ❌             |
| `turn purple`                           | `unknown_request` | `color_blue` ❌            |
| `make a square`                         | `unknown_request` | `move_center` ❌           |
| `go blue`                               | `color_blue`      | `move_left` ❌ (regression)|
| `go green`                              | `color_green`     | `move_left` ❌ (regression)|
| `can you become the color of the ocean` | `color_blue`      | `bounce` ❌ (regression)   |
| `go to another spot`                    | any move          | `guardrailViolation` ❌    |

The second attempt did not fix the boundaries. It also introduced two
new failure modes:

- **Regression**: `go blue`, `go green`, and the "color of the ocean"
  paraphrase passed in the first prompt, but now fail.
- **Guardrail false positive**: a benign movement transcript triggered
  `"Response may contain sensitive or unsafe content"`.

### Findings

1. **The model is sensitive to prompt changes in a non-monotonic way.**
   Fixing one case broke another. Prompt iteration is not a reliable
   path to correctness for this task.

2. **Small models collapse unsupported values into the nearest supported
   value.** When a color is not in the enum, the model tends to pick the
   first plausible color (`blue`) rather than `unsupported_color`. Same
   for movement targets (`center`). This is consistent with how
   constrained decoding biases small models toward always emitting a
   valid token.

3. **Meta-rules ("if X then Y, unless Z") are not reliably followed.**
   The model responds to concrete examples, not to conditional logic.
   This limits how much of the classification policy can be expressed
   in the system instructions.

4. **`guardrailViolation` can fire on benign inputs.** "move somewhere"
   is not sensitive content. The guardrail classifier is a separate
   failure mode that is not addressed by prompt engineering.

5. **The task has a closed grammar.** Ten labels, well-defined
   boundaries, deterministic expected outputs. This is the regime where
   deterministic command routing is easier to reproduce, easier to test
   in CI, cheaper to run, and independent of Apple Intelligence.

### Prompt-sensitivity and consistent failure modes

The model is deterministic for a given prompt: two runs of the same
prompt on the same machine produced identical outputs for every
transcript, including the failures.

However, the model's behavior changes discontinuously when the prompt
changes. The baseline prompt (before the schema revision) and the
revised prompt (after) produce different failure modes:

- Baseline: unsupported colors and moves collapsed to `move_center`
  or `color_blue`. `go blue`, `go green`, and `"can you become the
  color of the ocean"` passed.
- Revised: unsupported colors and moves collapse to `move_left` or
  `bounce`. `go blue`, `go green`, and `"can you become the color
  of the ocean"` now fail.

The revised prompt did not fix the boundary failures, and it
introduced regressions in cases that previously passed. This is not
non-determinism between runs; it is a stable response to a prompt
that the model cannot follow correctly.

The specific failure mode is consistent: the model refuses to emit
`unsupported_color` and instead collapses to the nearest valid
label. It appears unable to follow the negation rule "if the color
is not in {blue, red, green}, choose unsupported_color". Instead, it
picks a color or movement label that matches the verb pattern.

The `guardrailViolation` is also deterministic per prompt: it fires
on `"move somewhere"` under the baseline prompt and on
`"go to another spot"` under the revised prompt, consistently across
runs.

Implication: iterating on the prompt is not a path to correctness.
The model has a structural limitation with negation rules, not a
stochastic one. The current code keeps this resolver characterized and
experimental rather than treating prompt iteration as a production fix.

### Known limits

- **`SystemLanguageModel(useCase: .contentTagging)`** is optimized for
  entity tagging, not for instruction following with closed grammars.
  It was chosen initially for availability reasons, not suitability.
- **`SystemLanguageModel.default`** is used by the current resolver and
  follows some supported commands better, but still violates unsupported
  color boundaries in characterization tests.
- **Simulators** can start the test but cannot run inference. The
  integration suite is opt-in and must run on a real Mac with Apple
  Intelligence enabled and local model assets downloaded.
- **CI** cannot run the integration suite. Results are not reproducible
  across machines.
- **Latency** was not measured. Anecdotally, each `resolve` call
  dominated the test wall-clock time (≈10s for 12 transcripts).

### Why `turn purple` collapses to `blue` (and `go purple` does not)

The failure is verb-context dependent, not purely geometric.

**Hypothesis considered (geometric proximity).** The initial hypothesis
was that `purple` and `blue` are adjacent in the model's internal
representation space, and the model picks the nearest supported color
when it must emit a label from the enum. This hypothesis predicts that
*any* occurrence of `purple` in a color context would collapse to
`blue`.

**Result: the hypothesis is insufficient.** The model behaves
differently depending on the verb:

| Transcript | Observed |
|---|---|
| `turn purple` | `color_blue` (collapse) |
| `go purple` | `unknown` (correct) |
| `become purple` | `unknown` (correct) |

If geometric proximity were the whole story, all three would collapse
to `blue`. They do not. The geometric proximity of `purple` to `blue`
is a *necessary* condition for the collapse, but not *sufficient*. The
verb context is what triggers it.

**Refined explanation (verb association).** The model has a strong
association `turn -> color_X`, learned from common English
constructions like "turn blue", "turn red", "turn green". When the
color is ambiguous - `purple` is geometrically close enough to `blue`
- the `turn` context biases the model to pick the nearest supported
color. For other verbs, the association is weaker, and the model
emits `unknown` correctly.

This refined explanation is itself a hypothesis. It is consistent with
the observed data but was not tested directly (e.g., by measuring the
model's internal state or by testing additional verbs). It should be
treated as the best current explanation, not as established fact.

**Implication for prompt design.** Adding more examples of `purple =>
unsupported_color` will not fix `turn purple`. If the verb association
hypothesis is correct, the problem is not pattern learning; the model
already has a strong prior for `turn -> color_X` that overrides the
example. The fix would require either (a) accepting the limitation and
documenting it, or (b) removing `turn` from the supported verb
vocabulary, which is not acceptable.

### Session reuse

The resolver was changed to reuse a single `LanguageModelSession`
across calls instead of creating a fresh one per `resolve`. The
hypothesis was that session contamination might explain some of the
observed behavior.

**Result: no observable difference.** `turn purple`, `go yellow`, and
`go crimson` behaved identically before and after the change. The
integration suite continued to pass 17/17, and the semantic
approximation suite showed the same `turn purple -> color_blue` result.

Two interpretations are possible, and the data does not distinguish
between them:

1. **Session contamination does not happen at this call volume.** The
   test suite runs fewer than 30 calls in a session. The transcript
   may not accumulate enough context to influence subsequent
   classifications at this scale.

2. **The model is robust enough that contamination never happens for
   this task.** The classification is local enough - a single
   transcript in, a single label out - that the session history does
   not alter the output, regardless of how much accumulates.

A dedicated contamination test would distinguish between these: for
example, running `turn blue` followed by `turn purple` in the same
session and comparing against `turn purple` alone in a fresh session.
This test was not performed.

### Decision

Stop iterating on the prompt. The model does not meet the reliability
bar for this task by prompt/schema work alone.

The model is deterministic per prompt but cannot follow the
negation rule required by this task, and prompt iteration produced
regressions rather than fixes. There is no reason to expect a
different prompt to behave differently.

The Foundation Models implementation is kept documented as experimental
and covered by opt-in characterization tests. It should be re-evaluated
when the framework matures or a different use case becomes available.

`CommandResolverFallbackOrchestrator` currently remains the production
resolver registered in `AppContainer`. Its fixed order tries
`FoundationModelsCommandResolver` first, then `CoreMLModelCommandResolver`,
then `NetworkingResolver`. If Foundation Models returns `.unknown` or
throws, fallback can continue. If it returns an incorrect but executable
command, fallback does not run.

### References

- `FoundationModelsCommandResolver.swift` — the experimental implementation.
- `FoundationModelsCommandResolverIntegrationTests.swift` — opt-in integration suite.
- `FoundationModelsCommandResolverSemanticApproximationTests.swift` — opt-in characterization suite.
- `FoundationModelsCommandResolverColorGeneralizationTests.swift` — opt-in characterization suite.
- `CommandResolver` — protocol both implementations conform to.
- `CommandResolverFallbackOrchestrator` — composes resolvers in priority order.

## Color generalization scope

The resolver is expected to preserve a strict unsupported-color boundary:
only supported colors should produce executable color commands, while
unsupported colors and unrelated targets should resolve to `unknown`.

The Foundation Model was probed to see how far it generalizes beyond
explicit color words, and where it breaks. Three categories were tested:

### Category 1: Metaphors for supported colors

| Transcript | Expected | Observed |
|---|---|---|
| `the color of the ocean` | blue | blue |
| `the color of the sky` | blue | blue |
| `the color of water` | blue | unknown |
| `the color of midnight` | blue | blue |
| `the color of grass` | green | green |
| `the color of leaves` | green | green |
| `the color of fire` | red | red |
| `the color of blood` | red | unknown |

### Category 2: Single-word color generalization

| Transcript | Expected | Observed |
|---|---|---|
| `cobalt` | blue | blue |
| `sapphire` | blue | blue |
| `cerulean` | blue | blue |
| `ruby` | red | red |
| `vermillion` | red | unknown |
| `jade` | green | green |
| `lime` | green | unknown |
| `mint` | green | unknown |

### Category 3: Unsupported color boundaries

| Transcript | Expected | Observed |
|---|---|---|
| `go navy` | unknown | blue |
| `go teal` | unknown | blue |
| `go magenta` | unknown | unknown |
| `go coral` | unknown | red |
| `go crimson` | unknown | unknown |
| `go olive` | unknown | green |
| `go maroon` | unknown | unknown |

### Interpretation

The model does generalize some metaphors and uncommon color words
correctly: ocean, sky, midnight, grass, leaves, fire, cobalt, sapphire,
cerulean, ruby, and jade all map to the expected supported colors.
However, the generalization is incomplete: water and blood are rejected,
and several reasonable single-word colors (`vermillion`, `lime`, `mint`)
also return `unknown`.

The larger issue is that the model does not reliably stay in bounds for
the unsupported list. `go navy`, `go teal`, `go coral`, and `go olive`
all collapse to supported colors even though they are documented as
unsupported boundaries for this investigation.

### Implication for the resolver choice

The LLM adds some real semantic reach, but the scope is too uneven to
justify its cost for production command routing. The added capability is
partial, while the downside is concrete: latency, dependency on Apple
Intelligence, no CI coverage, and out-of-policy color collapses for words
that should stay unsupported. For this command grammar, the Foundation
Models resolver should remain experimental until unsupported-boundary
handling is reliable.
