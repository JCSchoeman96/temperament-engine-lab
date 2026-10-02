# Proof and Semantics Hardening Implementation Plan

> **For agentic workers:** Execute this plan inline in the existing isolated worktree, test first, and verify the full contract before reporting completion.

**Goal:** Strengthen generated-methodology correctness properties and make analysis, ranking, presentation, identifier, and error contracts harder to misuse.

**Architecture:** Keep scoring arithmetic unchanged. Generate structurally varied valid methodologies in StreamData, then check scorer, analyzer, ranking, and presentation invariants against those values. Make theoretical ranges explicitly channel-scoped and marginal, expose competition ranking as groups with place and score, and validate generated presentations before returning success.

**Tech Stack:** Elixir 1.20, Mix, ExUnit, StreamData 1.4.

---

### Task 1: Generate varied methodologies and prove core invariants

**Files:**
- Modify: `test/support/generators.ex`
- Modify: `test/temperament_engine/property/scoring_properties_test.exs`
- Modify: `test/temperament_engine/property/presentation_properties_test.exs`

- [x] Generate dimensions, questions, question types, response counts, positive integer weights, sparse multi-dimension contribution maps, and semantic IDs; derive complete answer maps from each generated methodology.
- [x] Replace fixed-fixture properties with 300-run properties for validation/scoring, trace totals, analyzer score bounds, response-order invariance, question-order score/ranking invariance with canonical trace order, presentation validity/corruption rejection, and ranking group invariants.
- [x] Run the property test files and confirm failures are caused by the not-yet-implemented API expectations.

### Task 2: Make theoretical ranges channel-only and marginal

**Files:**
- Modify: `lib/temperament_engine/methodology/analysis.ex`
- Modify: `lib/temperament_engine/methodology/analyzer.ex`
- Modify: `test/temperament_engine/methodology_analyzer_test.exs`

- [x] Replace aggregate fields with `by_channel`; each channel range contains `marginal_minimum_by_dimension` and `marginal_maximum_by_dimension`.
- [x] Generate warnings only from a channel's marginal maximum map, with the channel included in the warning path.
- [x] Assert mixed-channel analysis exposes no all-channel score opportunity and documents that separate marginal extrema need not form one jointly reachable vector.

### Task 3: Return competition-rank groups

**Files:**
- Modify: `lib/temperament_engine/scoring/ranking.ex`
- Modify: `lib/temperament_engine/scoring/scorer.ex`
- Modify: `lib/temperament_engine/result.ex`
- Modify: `test/temperament_engine/ranking_test.exs`
- Modify: `test/temperament_engine/scorer_test.exs`
- Modify: `test/temperament_engine/property/scoring_properties_test.exs`

- [x] Return groups shaped as `%{place: integer, score: integer, dimensions: [id]}`; places advance by the prior group's size, preserving competition ranking.
- [x] Keep dimension declaration order within tied groups and preserve exact ties without tie-breaking.
- [x] Update scorer expectations and test complete, unique, descending groups with correct competition places.

### Task 4: Validate presentation-generator postconditions

**Files:**
- Modify: `lib/temperament_engine/presentation/generator.ex`
- Modify: `test/temperament_engine/presentation_generator_test.exs`

- [x] Add a test where a one-argument shuffler returns malformed orders and assert generation returns validation errors.
- [x] Validate the constructed presentation against the methodology before returning `{:ok, presentation}`.

### Task 5: Harden types, identifiers, and error documentation

**Files:**
- Modify: `lib/temperament_engine/methodology.ex`
- Modify: `lib/temperament_engine/question.ex`
- Modify: `lib/temperament_engine/response.ex`
- Modify: `lib/temperament_engine/result.ex`
- Modify: `lib/temperament_engine/presentation.ex`
- Modify: `lib/temperament_engine/trace_entry.ex`
- Modify: `lib/temperament_engine/validation_error.ex`
- Modify: `lib/temperament_engine/methodology/validator.ex`
- Modify: `lib/temperament_engine.ex`
- Modify: `docs/TECHNICAL_SPEC.md`
- Modify: `docs/METHODOLOGY_SPEC.md`
- Modify: `docs/BUILD_CONTRACT.md`

- [x] Define types for the six public data structures and specs for every facade function.
- [x] Accept only ASCII IDs matching `[A-Za-z0-9][A-Za-z0-9._-]*`; reject whitespace, control characters, and non-ASCII IDs without normalization.
- [x] Document `ValidationError.code` plus `path` as the stable machine interface and `detail` as diagnostic text; document marginal ranges and rank-group places.

### Task 6: Treat test compilation warnings as CI failures

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/BUILD_CONTRACT.md`

- [x] Keep `mix compile --warnings-as-errors` and run `MIX_ENV=test mix do compile --warnings-as-errors + test --warnings-as-errors` as the test gate.
- [x] Format the project and run the full CI command set with Elixir 1.20.

**Final verification:**

```bash
mix format --check-formatted
mix compile --warnings-as-errors
MIX_ENV=test mix do compile --warnings-as-errors + test --warnings-as-errors
mix run examples/baseline_demo.exs
mix run examples/mixed_format_demo.exs
```
