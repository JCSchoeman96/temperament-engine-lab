defmodule TemperamentEngine.Result do
  @moduledoc "Deterministic channel scores, ranking and calculation trace."

  defstruct methodology_id: nil,
            methodology_version: nil,
            channel_scores: %{},
            ranking_scores: nil,
            ranking: nil,
            top_tie?: nil,
            trace: []
end
