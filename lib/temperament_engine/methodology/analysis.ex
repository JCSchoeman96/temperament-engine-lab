defmodule TemperamentEngine.Methodology.Analysis do
  @moduledoc """
  Structural scoring diagnostics implied by the methodology's response definitions.

  Question vectors are complete weighted vectors over the declared dimensions, with omitted
  contributions treated as zero. Minimum and maximum values are marginal for each dimension. The
  maxima across dimensions can come from different responses and therefore do not necessarily
  describe a jointly reachable score vector. Diagnostics do not apply thresholds or approve a
  methodology.
  """

  defstruct by_channel: %{}, by_question: %{}, warnings: []

  @type channel :: :forced_choice | :agreement_scale
  @type dimension_range :: %{optional(String.t()) => non_neg_integer()}
  @type channel_range :: %{
          marginal_minimum_by_dimension: dimension_range(),
          marginal_maximum_by_dimension: dimension_range(),
          maximum_single_question_swing_by_dimension: dimension_range()
        }
  @type question_analysis :: %{
          channel: channel(),
          marginal_minimum_by_dimension: dimension_range(),
          marginal_maximum_by_dimension: dimension_range(),
          marginal_swing_by_dimension: dimension_range(),
          response_count: pos_integer(),
          distinct_scoring_vector_count: pos_integer(),
          duplicate_scoring_vector_groups: [[String.t()]],
          non_discriminating?: boolean()
        }
  @type warning :: %{code: atom(), path: [term()], detail: String.t()}

  @type t :: %__MODULE__{
          by_channel: %{optional(channel()) => channel_range()},
          by_question: %{optional(String.t()) => question_analysis()},
          warnings: [warning()]
        }
end
