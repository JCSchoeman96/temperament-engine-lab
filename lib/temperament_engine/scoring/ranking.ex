defmodule TemperamentEngine.Scoring.Ranking do
  @moduledoc "Groups dimensions by descending integer score with explicit competition places."

  @type rank_group :: %{place: pos_integer(), score: non_neg_integer(), dimensions: [String.t()]}
  @type scores :: %{optional(String.t()) => non_neg_integer()}

  @spec rank(scores(), [String.t()]) :: [rank_group()]
  def rank(scores, dimensions) when is_map(scores) and is_list(dimensions) do
    score_levels =
      dimensions
      |> Enum.map(&Map.get(scores, &1, 0))
      |> Enum.uniq()
      |> Enum.sort(:desc)

    {groups, _next_place} =
      Enum.map_reduce(score_levels, 1, fn score, place ->
        members = Enum.filter(dimensions, &(Map.get(scores, &1, 0) == score))
        {%{place: place, score: score, dimensions: members}, place + length(members)}
      end)

    groups
  end

  @spec top_tie?([rank_group()]) :: boolean()
  def top_tie?([%{dimensions: [_first, _second | _]} | _]), do: true
  def top_tie?(_ranking), do: false
end
