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

For each question and dimension, the analyzer evaluates all valid responses, treats omissions as zero, applies the question weight, and adds the per-question minimum and maximum. Different maximum opportunity across dimensions is reported as a warning for research review; it does not change the score.

## Research limitations

The fixtures demonstrate engine mechanics only. They do not establish validated constructs, final items, calibrated weights, cross-channel comparability, or a justified composite score.
