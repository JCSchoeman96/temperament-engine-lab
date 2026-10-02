# Build contract

This contract records the required boundaries and invariants for `temperament-engine-lab`.

## Repository boundary

- This is a standalone pure Elixir research library with tests and runnable examples.
- It is not a NewYou implementation and does not depend on or modify the NewYou repository.
- Synthetic assessment content only; do not add proprietary or source-book question prose.
- Do not publish a Hex package.
- Do not add production modules beyond the specified engine structures and mechanisms without a concrete requirement.

## Runtime and dependencies

- Elixir requirement: `~> 1.20`.
- Zero runtime dependencies.
- The only allowed dependency is `{:stream_data, "~> 1.4", only: :test}`.
- No Phoenix, Ash, Ecto, PostgreSQL, Oban, PubSub, ETS, Redis, GenServers, OTP supervision tree, HTTP API, persistence, authentication, UI, JavaScript, or external services.

## Scoring invariants

- Question types are exactly `:forced_choice` and `:agreement_scale`.
- A question weight is an integer of at least one; contributions are non-negative integers.
- Effective contribution is question weight multiplied by the selected response's contribution.
- Missing dimension contributions mean zero; empty contribution maps are valid.
- Contributions reference declared dimension IDs only. Dimensions remain methodology data; the scorer has no color-specific control flow.
- Answers are complete maps of stable question IDs to stable response IDs. Missing, extra, unknown, and wrong-question answers fail closed.
- Display positions never carry scoring meaning. Metadata never changes a score.
- Channel scores remain separate. No channel weighting or cross-channel composition is implemented.
- Ranking is either disabled or sourced from the forced-choice channel. Exact equal integer scores remain explicit groups with competition `place`, exact `score`, and tied `dimensions`; declaration order never breaks a tie.
- Trace entries are emitted during the same canonical question reduction that computes channel totals. For each channel and dimension, the score equals the sum of matching trace weighted contributions.
- Scoring depends only on the methodology and semantic answer map. Trace order follows methodology question order.

## Methodology and presentation invariants

- Methodology ID, version, dimensions, question IDs, and response IDs match the ASCII machine-ID grammar `[A-Za-z0-9][A-Za-z0-9._-]*`; the engine rejects other values without trimming or normalization. Dimension and question IDs are unique, and response IDs are unique within each question.
- Methodology contains at least one dimension and question; every question has at least one response.
- Ranking source is only `{:channel, :forced_choice}` or `:none`; an enabled source must exist.
- Presentation contains every methodology question and every valid response exactly once, with matching methodology ID and version. A successful generator result has passed presentation validation.
- Question order is shuffled for each generated presentation. Every forced-choice response list is independently shuffled. Agreement responses retain their declared order.
- Randomness uses standard Elixir/OTP facilities. Correctness does not rely on a seed, and tests do not require separate random presentations to differ.
- The analyzer reports channel-scoped `marginal_minimum_by_dimension`, `marginal_maximum_by_dimension`, and `maximum_single_question_swing_by_dimension` maps, plus per-question diagnostics keyed by question ID. Per-question ranges and swings include question weight. Duplicate-vector comparison uses a complete weighted vector across declared dimensions, with omitted contributions treated as zero; duplicate groups retain response declaration order within each group. `non_discriminating?` is true exactly when a question has one distinct scoring vector, including a question with one response.
- Marginal extrema are calculated independently for each dimension and need not form one jointly reachable score vector. Warnings expose stable `code` and `path` fields: `:unequal_maximum_opportunity` identifies channel-level differences, and `:zero_score_opportunity` identifies an exact channel and dimension whose maximum is zero. Warning prose is explanatory only.
- Analyzer diagnostics are mathematical and structural observations. They do not apply thresholds, approve or reject a methodology, or infer psychological or clinical quality. Analysis does not change scoring arithmetic, channel separation, or the trace.
- StreamData properties generate varied valid methodologies and prove score, trace, analysis-range, ranking, declaration-order, and presentation invariants.
- Validation error `code` and `path` are the stable machine interface; `detail` is diagnostic copy.

## Explicit non-features

Do not implement participant accounts, assessment attempts, save/resume persistence, expiry, entitlements, payments, methodology publishing or approval workflows, tie-break questions, manual review, current temperament profiles, reports, translations, score-distance labels, normalization, cross-channel composite scoring, database schemas, Ash resources, Phoenix UI, HTTP endpoints, or external service integrations.

## Required completion commands

```bash
mix deps.get
mix format
mix format --check-formatted
mix compile --warnings-as-errors
MIX_ENV=test mix do compile --warnings-as-errors + test --warnings-as-errors
mix run examples/baseline_demo.exs
mix run examples/mixed_format_demo.exs
```
