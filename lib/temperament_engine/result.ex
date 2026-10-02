defmodule TemperamentEngine.Result do
  @moduledoc "Deterministic channel scores, ranking and calculation trace."

  alias TemperamentEngine.Scoring.Ranking
  alias TemperamentEngine.TraceEntry

  defstruct methodology_id: nil,
            methodology_version: nil,
            channel_scores: %{},
            ranking_scores: nil,
            ranking: nil,
            top_tie?: nil,
            trace: []

  @type dimension_scores :: %{optional(String.t()) => non_neg_integer()}
  @type channel_scores :: %{optional(TraceEntry.channel()) => dimension_scores()}
  @type t :: %__MODULE__{
          methodology_id: String.t() | nil,
          methodology_version: String.t() | nil,
          channel_scores: channel_scores(),
          ranking_scores: dimension_scores() | nil,
          ranking: [Ranking.rank_group()] | nil,
          top_tie?: boolean() | nil,
          trace: [TraceEntry.t()]
        }
end
