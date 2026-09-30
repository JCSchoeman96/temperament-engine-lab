defmodule TemperamentEngine.Methodology.Analyzer do
  @moduledoc "Calculates theoretical score opportunity without participant answers."

  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Methodology.Analysis
  alias TemperamentEngine.Methodology.Validator

  @spec analyze(term()) :: {:ok, Analysis.t()} | {:error, list()}
  def analyze(methodology) do
    with :ok <- Validator.validate(methodology) do
      {:ok, calculate(methodology)}
    end
  end

  defp calculate(%Methodology{} = methodology) do
    overall = empty_range(methodology.dimensions)

    channels =
      methodology.questions
      |> Enum.map(&channel_for_type(&1.type))
      |> Enum.uniq()

    channel_ranges = Map.new(channels, &{&1, empty_range(methodology.dimensions)})

    {overall, channel_ranges} =
      Enum.reduce(methodology.questions, {overall, channel_ranges}, fn question,
                                                                       {totals, by_channel} ->
        channel = channel_for_type(question.type)
        question_range = question_range(question, methodology.dimensions)
        next_totals = add_ranges(totals, question_range)
        next_channel = add_ranges(Map.fetch!(by_channel, channel), question_range)
        {next_totals, Map.put(by_channel, channel, next_channel)}
      end)

    warnings =
      unequal_opportunity_warnings(
        overall.maximum_by_dimension,
        [:maximum_by_dimension],
        :all_channels
      ) ++
        Enum.flat_map(channels, fn channel ->
          range = Map.fetch!(channel_ranges, channel)

          unequal_opportunity_warnings(
            range.maximum_by_dimension,
            [:by_channel, channel, :maximum_by_dimension],
            channel
          )
        end)

    %Analysis{
      minimum_by_dimension: overall.minimum_by_dimension,
      maximum_by_dimension: overall.maximum_by_dimension,
      by_channel: channel_ranges,
      warnings: warnings
    }
  end

  defp question_range(question, dimensions) do
    per_dimension =
      Map.new(dimensions, fn dimension ->
        weighted_values =
          Enum.map(question.responses, fn response ->
            Map.get(response.contributions, dimension, 0) * question.weight
          end)

        {dimension, {Enum.min(weighted_values), Enum.max(weighted_values)}}
      end)

    %{
      minimum_by_dimension:
        Map.new(per_dimension, fn {dimension, {minimum, _}} -> {dimension, minimum} end),
      maximum_by_dimension:
        Map.new(per_dimension, fn {dimension, {_, maximum}} -> {dimension, maximum} end)
    }
  end

  defp empty_range(dimensions) do
    zeroes = Map.new(dimensions, &{&1, 0})
    %{minimum_by_dimension: zeroes, maximum_by_dimension: zeroes}
  end

  defp add_ranges(left, right) do
    %{
      minimum_by_dimension:
        Map.new(left.minimum_by_dimension, fn {dimension, value} ->
          {dimension, value + Map.fetch!(right.minimum_by_dimension, dimension)}
        end),
      maximum_by_dimension:
        Map.new(left.maximum_by_dimension, fn {dimension, value} ->
          {dimension, value + Map.fetch!(right.maximum_by_dimension, dimension)}
        end)
    }
  end

  defp unequal_opportunity_warnings(maximums, path, scope) do
    if Map.values(maximums) |> Enum.uniq() |> length() > 1 do
      [
        %{
          code: :unequal_maximum_opportunity,
          path: path,
          detail: "Maximum score opportunity differs across dimensions in #{scope} scope."
        }
      ]
    else
      []
    end
  end

  defp channel_for_type(:forced_choice), do: :forced_choice
  defp channel_for_type(:agreement_scale), do: :agreement_scale
end
