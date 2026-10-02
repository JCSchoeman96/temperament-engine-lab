defmodule TemperamentEngine.Methodology.Analyzer do
  @moduledoc "Reports weighted marginal opportunities and per-question scoring-vector diagnostics."

  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Methodology.Analysis
  alias TemperamentEngine.Methodology.Validator
  alias TemperamentEngine.ValidationError

  @spec analyze(term()) :: {:ok, Analysis.t()} | {:error, [ValidationError.t()]}
  def analyze(methodology) do
    with :ok <- Validator.validate(methodology) do
      {:ok, calculate(methodology)}
    end
  end

  defp calculate(%Methodology{} = methodology) do
    channels =
      methodology.questions
      |> Enum.map(&channel_for_type(&1.type))
      |> Enum.uniq()
      |> Enum.sort()

    initial_by_channel = Map.new(channels, &{&1, empty_range(methodology.dimensions)})

    {by_channel, by_question} =
      Enum.reduce(methodology.questions, {initial_by_channel, %{}}, fn question,
                                                                       {by_channel, by_question} ->
        channel = channel_for_type(question.type)
        question_analysis = question_analysis(question, methodology.dimensions)

        updated_channel =
          add_question_analysis(Map.fetch!(by_channel, channel), question_analysis)

        {
          Map.put(by_channel, channel, updated_channel),
          Map.put(by_question, question.id, question_analysis)
        }
      end)

    warnings =
      Enum.flat_map(channels, fn channel ->
        range = Map.fetch!(by_channel, channel)

        zero_opportunity_warnings(
          range.marginal_maximum_by_dimension,
          methodology.dimensions,
          channel
        ) ++
          unequal_opportunity_warnings(
            range.marginal_maximum_by_dimension,
            [:by_channel, channel, :marginal_maximum_by_dimension],
            channel
          )
      end)

    %Analysis{
      by_channel: by_channel,
      by_question: by_question,
      warnings: warnings
    }
  end

  defp question_analysis(question, dimensions) do
    weighted_vectors =
      Enum.map(question.responses, fn response ->
        {response, complete_weighted_vector(response, question.weight, dimensions)}
      end)

    {minimums, maximums, swings} =
      Enum.reduce(dimensions, {%{}, %{}, %{}}, fn dimension, {minimums, maximums, swings} ->
        values =
          Enum.map(weighted_vectors, fn {_response, vector} -> Map.fetch!(vector, dimension) end)

        minimum = Enum.min(values)
        maximum = Enum.max(values)

        {
          Map.put(minimums, dimension, minimum),
          Map.put(maximums, dimension, maximum),
          Map.put(swings, dimension, maximum - minimum)
        }
      end)

    distinct_vector_count =
      weighted_vectors
      |> Enum.map(fn {_response, vector} -> vector end)
      |> MapSet.new()
      |> MapSet.size()

    %{
      channel: channel_for_type(question.type),
      marginal_minimum_by_dimension: minimums,
      marginal_maximum_by_dimension: maximums,
      marginal_swing_by_dimension: swings,
      response_count: length(question.responses),
      distinct_scoring_vector_count: distinct_vector_count,
      duplicate_scoring_vector_groups: duplicate_vector_groups(weighted_vectors),
      non_discriminating?: distinct_vector_count == 1
    }
  end

  defp complete_weighted_vector(response, weight, dimensions) do
    Map.new(dimensions, fn dimension ->
      {dimension, weight * Map.get(response.contributions, dimension, 0)}
    end)
  end

  defp duplicate_vector_groups(weighted_vectors) do
    weighted_vectors
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{response, vector}, index}, groups ->
      Map.update(groups, vector, [{index, response.id}], &[{index, response.id} | &1])
    end)
    |> Map.values()
    |> Enum.filter(&(length(&1) > 1))
    |> Enum.map(&Enum.reverse/1)
    |> Enum.sort_by(fn [{first_index, _response_id} | _rest] -> first_index end)
    |> Enum.map(fn group -> Enum.map(group, fn {_index, response_id} -> response_id end) end)
  end

  defp empty_range(dimensions) do
    zeroes = Map.new(dimensions, &{&1, 0})

    %{
      marginal_minimum_by_dimension: zeroes,
      marginal_maximum_by_dimension: zeroes,
      maximum_single_question_swing_by_dimension: zeroes
    }
  end

  defp add_question_analysis(channel_analysis, question_analysis) do
    %{
      marginal_minimum_by_dimension:
        add_ranges(
          channel_analysis.marginal_minimum_by_dimension,
          question_analysis.marginal_minimum_by_dimension
        ),
      marginal_maximum_by_dimension:
        add_ranges(
          channel_analysis.marginal_maximum_by_dimension,
          question_analysis.marginal_maximum_by_dimension
        ),
      maximum_single_question_swing_by_dimension:
        Map.new(channel_analysis.maximum_single_question_swing_by_dimension, fn {dimension,
                                                                                 maximum} ->
          {dimension,
           max(maximum, Map.fetch!(question_analysis.marginal_swing_by_dimension, dimension))}
        end)
    }
  end

  defp add_ranges(left, right) do
    Map.new(left, fn {dimension, value} -> {dimension, value + Map.fetch!(right, dimension)} end)
  end

  defp zero_opportunity_warnings(maximums, dimensions, channel) do
    Enum.flat_map(dimensions, fn dimension ->
      if Map.fetch!(maximums, dimension) == 0 do
        [
          %{
            code: :zero_score_opportunity,
            path: [:by_channel, channel, :marginal_maximum_by_dimension, dimension],
            detail: "No response in the #{channel} channel can contribute to this dimension."
          }
        ]
      else
        []
      end
    end)
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
