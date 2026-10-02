# Research technical specification

**RESEARCH / NON-AUTHORITATIVE**  
**NOT NEWYOU IMPLEMENTATION AUTHORITY**

## Runtime and dependency boundary

The project targets Elixir `~> 1.20`. It has no runtime dependencies. StreamData `~> 1.4` is the only dependency and is included only in the test environment. There is no application supervision tree, process state, persistence, network client, or framework integration.

## Public API

`TemperamentEngine` is the facade:

```elixir
validate_methodology(methodology)
analyze_methodology(methodology)
generate_presentation(methodology)
validate_presentation(methodology, presentation)
score(methodology, answers)
```

Validators return `:ok` or `{:error, errors}`. Operations that return data use `{:ok, value}` or `{:error, errors}`. Each error is a `TemperamentEngine.ValidationError`. The stable machine interface is `code` plus `path`; `detail` is diagnostic copy and may change.

## Data model

The production modules are limited to the facade and the structures and focused mechanisms listed below:

- `Methodology`, `Question`, `Response`, `Presentation`, `Result`, `TraceEntry`, `ValidationError`
- `Methodology.Analysis`, `Methodology.Analyzer`, `Methodology.Validator`
- `Presentation.Generator`, `Presentation.Validator`
- `Scoring.Scorer`, `Scoring.Ranking`

External identifiers are ASCII machine IDs matching `[A-Za-z0-9][A-Za-z0-9._-]*`. The engine rejects rather than trims or normalizes other values, and never converts identifiers into atoms. Dimensions and questions retain methodology declaration order. Metadata is a map and is ignored by scoring.

## Validation

Methodology validation checks machine IDs and versions, a non-empty unique dimension list, a non-empty unique question list, supported types, integer weights of at least one, at least one response per question, unique response IDs within each question, declared contribution dimensions, non-negative integer contributions, metadata shape, and supported ranking source availability.

Presentation validation checks methodology identity and version, exact question membership, exact per-question response membership, duplicates, missing values, unknown values, and responses assigned to the wrong question. Scoring validates the methodology and complete answer map before calculating any result.

## Calculation

For each answered question, the scorer resolves the response by semantic ID, derives its channel from question type, fills omitted dimension contributions with zero, multiplies by the question weight, and updates channel totals and the trace in one reduction over canonical methodology question order. All arithmetic is integer arithmetic.

Channel keys are `:forced_choice` and `:agreement_scale`. Only channels present in the methodology appear in `channel_scores`. No cross-channel total is produced. The ranking source, when enabled, is the forced-choice channel only.

Ranking groups dimensions by descending score. Each group includes its competition place, exact score, and tied dimensions. For example, a two-dimension tie at first place is followed by place `3`. Methodology dimension order is used only to present members within a group. `top_tie?` reports whether the first group has multiple dimensions.

## Analysis

The analyzer calculates each question's minimum and maximum weighted contribution for each dimension, then sums those opportunities within each channel. It returns `by_channel` ranges named `marginal_minimum_by_dimension` and `marginal_maximum_by_dimension`; there is no all-channel aggregate. Extrema are marginal, so maxima for different dimensions can come from different answers and need not form one reachable score vector. Unequal maximum opportunities produce structured, channel-scoped warnings. Analysis does not modify scorer behavior or create a composite result.

## Randomization

The production generator uses `Enum.shuffle/1` for the complete question list and separately for each forced-choice response list. Agreement response order is copied unchanged. It validates the generated presentation before returning success, so `{:ok, presentation}` always means the presentation is valid for that methodology. An internal function argument permits deterministic tests; normal facade use does not require or depend on a seed.

## Determinism and trace invariant

Scoring reads neither presentation order nor map enumeration order. Trace order follows methodology question order. For every returned channel and dimension, the score equals the sum of matching trace weighted contributions.
