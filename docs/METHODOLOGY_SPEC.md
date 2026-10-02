# Research methodology specification

**RESEARCH / NON-AUTHORITATIVE**  
**NOT NEWYOU IMPLEMENTATION AUTHORITY**

## Methodology data is explicit

Scoring meaning comes from the methodology's stable dimension IDs, question types, positive integer question weights, response IDs, and non-negative integer contribution maps. Metadata is optional research information and never changes scoring.

Dimensions are methodology data; the scorer contains no dimension-specific branches. A response may contribute to multiple declared dimensions. An omitted dimension has contribution zero, and an empty contribution map is valid.

## Synthetic baseline

The regression fixture contains exactly 25 synthetic forced-choice questions. Each has four synthetic responses, weight `1`, and one-hot contribution mappings:

| Response suffix | Dimension contribution |
| --- | --- |
| `a` | `yellow: 1` |
| `b` | `red: 1` |
| `c` | `green: 1` |
| `d` | `blue: 1` |

There are no copied assessment prompts. The compatibility test compares the engine output with an ordinary count of selected dimensions.

## Synthetic agreement scale

Agreement response IDs are declared in this fixed order:

1. `strongly_disagree`
2. `disagree`
3. `agree`
4. `strongly_agree`

The mixed-format fixture defines its example contribution values on each response: `0`, `1`, `2`, and `3`, respectively. These values are not engine constants. Agreement response order is never shuffled.

## Weights and channels

The baseline and mixed-format research methodologies start with item weight `1`. A separate synthetic weighted fixture uses weights greater than one to demonstrate the mechanism and includes unequal per-response contributions and one response contributing to more than one dimension.

Question type determines the evidence channel:

- `:forced_choice` → `:forced_choice`
- `:agreement_scale` → `:agreement_scale`

The result retains channel scores separately. No channel weights, normalization, or combined ranking are defined here. Ranking can be enabled only from the forced-choice channel; mixed examples use `ranking_source: :none`.

## Opportunity analysis

For each question and declared dimension, the analyzer evaluates every valid response, treats omissions as zero, applies question weight, and reports the marginal minimum, maximum, and swing. It also compares each response's complete weighted vector across all declared dimensions. Sparse and explicit-zero contribution maps therefore have the same scoring meaning. Per-question diagnostics include response count, distinct vector count, groups of responses with identical scoring vectors, and `non_discriminating?`, which is true exactly when all responses produce one distinct vector. This also applies to a question with one response.

Within each channel, minimums and maximums are summed across questions, while `maximum_single_question_swing_by_dimension` is the largest individual question swing for each dimension. A dimension's maximum can come from a different response than another dimension's maximum, so marginal extrema do not promise one jointly reachable score vector. `:unequal_maximum_opportunity` remains channel-scoped; `:zero_score_opportunity` identifies a channel and dimension whose maximum is zero. Warning `code` and `path` are the machine-facing contract; detail text is explanatory.

These diagnostics are mathematical and structural observations only. They apply no thresholds and do not determine whether a methodology is approved or psychologically or clinically appropriate. They do not change scoring arithmetic, channel separation, or the score result.

## Ranking result

When enabled, ranking groups include `place`, exact `score`, and tied `dimensions`. Places use competition ranking: a tie occupying first and second place is followed by place `3`. Equal scores remain tied, and methodology dimension order only controls the order of members within a group.

## Research limitations

The fixtures demonstrate engine mechanics only. They do not establish validated constructs, final items, calibrated weights, cross-channel comparability, or a justified composite score.
