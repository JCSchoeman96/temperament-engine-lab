# temperament-engine-lab

`temperament-engine-lab` is a standalone Elixir research library for deterministic, weighted temperament scoring and randomized assessment presentation. It contains only synthetic assessment definitions.

It is not the NewYou application, does not carry NewYou implementation authority, and does not read from or modify the NewYou repository. It has no web framework, database, persistence layer, OTP process tree, or external service. The calculation core is a plain Elixir library; the only dependency is StreamData, scoped to tests.

## Requirements

- Elixir `~> 1.20`
- Mix

## Run

```bash
mix deps.get
mix test
mix run examples/baseline_demo.exs
mix run examples/mixed_format_demo.exs
```

The public entry point is `TemperamentEngine`. It validates methodologies, analyzes theoretical score opportunity, generates and validates presentations, and scores complete maps of question IDs to response IDs.

Forced-choice and agreement-scale evidence remains in separate channel score maps. The engine creates a contribution trace during the same reduction used to compute those scores. Ranking is available only when a methodology explicitly selects the forced-choice channel.

This project is a research laboratory. It intentionally excludes participant accounts, attempts, persistence, reports, UI, HTTP APIs, payments, composite channel scoring, and other application behavior. See `docs/BUILD_CONTRACT.md` for the full boundary and invariants.
