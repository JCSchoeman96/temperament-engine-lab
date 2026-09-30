defmodule TemperamentEngine.Scoring.Ranking do
  @moduledoc "Groups dimensions by descending integer score while preserving explicit ties."

  def rank(scores, dimensions) when is_map(scores) and is_list(dimensions) do
    score_levels =
      dimensions
      |> Enum.map(&Map.get(scores, &1, 0))
      |> Enum.uniq()
      |> Enum.sort(:desc)

    Enum.map(score_levels, fn score ->
      Enum.filter(dimensions, &(Map.get(scores, &1, 0) == score))
    end)
  end

  def top_tie?([[_, _ | _] | _]), do: true
  def top_tie?(_ranking), do: false
end
