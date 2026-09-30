# Research product specification

**RESEARCH / NON-AUTHORITATIVE**  
**NOT NEWYOU IMPLEMENTATION AUTHORITY**

## Purpose

This project is a disposable research library for two related calculations:

1. Calculate exact integer scores from explicit methodology data and semantic response IDs.
2. Generate a randomized presentation order without changing response meaning.

The library is intended for modelling, synthetic examples, and regression tests. It does not define a production temperament assessment or claim that any synthetic methodology is psychometrically validated.

## Participant-facing assessment content

The project stores no source-book prompts. The baseline uses stable question and response IDs with one-hot dimension mappings. The mixed example uses synthetic IDs and synthetic contribution values. Question metadata can carry research notes, but metadata does not affect scoring.

## Methodology behavior

A methodology has a stable ID, version, ordered dimension IDs, ordered questions, and an explicit ranking source. Questions use one of two formats:

- `:forced_choice`: the question and its responses may be shuffled for presentation.
- `:agreement_scale`: the question may be shuffled, but its declared response order remains fixed.

Both types use the same weighted scoring equation. A selected response's contribution to a dimension is multiplied by the question's integer weight.

## Evidence and results

The engine returns forced-choice and agreement-scale totals separately. It does not assign channel weights or combine the channels. When ranking is enabled, the methodology must choose `{:channel, :forced_choice}`; ties remain explicit ranking groups. A methodology with `ranking_source: :none` returns `nil` for ranking fields.

Every result includes a canonical-order trace. Each entry records the question, selected response, channel, question weight, raw contribution vector, and weighted contribution vector. Missing dimensions in a response are represented as zero in the trace.

## Presentation behavior

Each presentation contains every methodology question once and every question's valid responses once. The presentation is tied to the methodology ID and version. It is an ordering artifact only; scoring accepts semantic response IDs and does not accept display positions.

## Supported research examples

- A synthetic 25-question, four-response baseline with unit weights and one-hot dimensions.
- A small mixed-format methodology that keeps forced-choice and agreement evidence separate.
- A weighted fixture demonstrating unequal question weights, unequal response contributions, and multi-dimension contributions.

## Explicit product boundary

This library does not implement participants, assessment attempts, saving or resuming, expiry, entitlements, payments, publishing or approval workflows, tie-break questions, manual review, profiles, reports, translations, normalization, score-distance labels, persistence, authentication, UI, APIs, or external integrations.
