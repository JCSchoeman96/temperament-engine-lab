defmodule TemperamentEngine.Property.ScoringPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData

  alias TemperamentEngine.Generators
  alias TemperamentEngine.Methodology.Analyzer

  property "generated valid methodologies accept complete answers without raising" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      assert :ok == TemperamentEngine.validate_methodology(methodology)
      assert {:ok, _result} = TemperamentEngine.score(methodology, answers)
    end
  end

  property "repeated generated scoring returns the same complete result" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      assert {:ok, first_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, second_result} = TemperamentEngine.score(methodology, answers)
      assert second_result == first_result
    end
  end

  property "answer maps built in different insertion orders score identically" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      entries = Map.to_list(answers)
      forward = Map.new(entries)
      reverse = Map.new(Enum.reverse(entries))

      assert forward == reverse
      assert {:ok, forward_result} = TemperamentEngine.score(methodology, forward)
      assert {:ok, reverse_result} = TemperamentEngine.score(methodology, reverse)
      assert forward_result == reverse_result
    end
  end

  property "common positive weight scaling preserves ranking places and ties" do
    check all(
            methodology <- Generators.ranked_methodologies(),
            answers <- Generators.answers_for(methodology),
            scale <- integer(1..10),
            max_runs: 300
          ) do
      scaled = %{
        methodology
        | questions: Enum.map(methodology.questions, &%{&1 | weight: &1.weight * scale})
      }

      assert {:ok, original_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, scaled_result} = TemperamentEngine.score(scaled, answers)

      assert scaled_result.ranking ==
               Enum.map(original_result.ranking, fn group ->
                 %{group | score: group.score * scale}
               end)

      assert scaled_result.ranking_scores ==
               Map.new(original_result.ranking_scores, fn {dimension, score} ->
                 {dimension, score * scale}
               end)

      assert scaled_result.top_tie? == original_result.top_tie?
    end
  end

  property "trace totals equal every generated channel score" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      assert {:ok, result} = TemperamentEngine.score(methodology, answers)
      assert trace_totals(methodology, result.trace) == result.channel_scores
    end
  end

  property "realized scores stay inside the analyzer's channel marginal ranges" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      assert {:ok, result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, analysis} = Analyzer.analyze(methodology)

      for {channel, scores} <- result.channel_scores,
          dimension <- methodology.dimensions do
        range = Map.fetch!(analysis.by_channel, channel)
        score = Map.fetch!(scores, dimension)

        assert Map.fetch!(range.marginal_minimum_by_dimension, dimension) <= score
        assert score <= Map.fetch!(range.marginal_maximum_by_dimension, dimension)
      end
    end
  end

  property "response declaration order does not change generated scores or ranking" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      reordered = %{
        methodology
        | questions:
            Enum.map(methodology.questions, fn question ->
              %{question | responses: Enum.reverse(question.responses)}
            end)
      }

      assert {:ok, original_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, reordered_result} = TemperamentEngine.score(reordered, answers)
      assert reordered_result.channel_scores == original_result.channel_scores
      assert reordered_result.ranking_scores == original_result.ranking_scores
      assert reordered_result.ranking == original_result.ranking
      assert reordered_result.top_tie? == original_result.top_tie?
    end
  end

  property "question declaration order preserves scores and ranking while tracing canonically" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      reordered = %{methodology | questions: Enum.reverse(methodology.questions)}

      assert {:ok, original_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, reordered_result} = TemperamentEngine.score(reordered, answers)
      assert reordered_result.channel_scores == original_result.channel_scores
      assert reordered_result.ranking_scores == original_result.ranking_scores
      assert reordered_result.ranking == original_result.ranking
      assert reordered_result.top_tie? == original_result.top_tie?

      assert Enum.map(reordered_result.trace, & &1.question_id) ==
               Enum.map(Enum.reverse(methodology.questions), & &1.id)
    end
  end

  property "ranking groups include every dimension once with competition places" do
    check all(
            methodology <- Generators.ranked_methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      assert {:ok, result} = TemperamentEngine.score(methodology, answers)
      groups = result.ranking
      dimensions = methodology.dimensions
      grouped_dimensions = Enum.flat_map(groups, & &1.dimensions)

      assert Enum.sort(grouped_dimensions) == Enum.sort(dimensions)
      assert Enum.frequencies(grouped_dimensions) == Map.new(dimensions, &{&1, 1})
      assert length(Enum.uniq_by(groups, & &1.score)) == length(groups)

      Enum.reduce(groups, 1, fn group, next_place ->
        assert group.place == next_place

        assert Enum.all?(group.dimensions, fn dimension ->
                 Map.fetch!(result.ranking_scores, dimension) == group.score
               end)

        next_place + length(group.dimensions)
      end)

      assert Enum.all?(Enum.chunk_every(groups, 2, 1, :discard), fn [higher, lower] ->
               higher.score > lower.score
             end)

      expected_top_tie = length(hd(groups).dimensions) > 1
      assert result.top_tie? == expected_top_tie
    end
  end

  property "explicit zero entries do not change generated scores or traces" do
    check all(
            methodology <- Generators.methodologies(),
            answers <- Generators.answers_for(methodology),
            max_runs: 300
          ) do
      explicit_zeroes = %{
        methodology
        | questions:
            Enum.map(methodology.questions, fn question ->
              responses =
                Enum.map(question.responses, fn response ->
                  zeroes = Map.new(methodology.dimensions, &{&1, 0})
                  %{response | contributions: Map.merge(zeroes, response.contributions)}
                end)

              %{question | responses: responses}
            end)
      }

      assert {:ok, original_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, explicit_result} = TemperamentEngine.score(explicit_zeroes, answers)
      assert explicit_result == original_result
    end
  end

  defp trace_totals(methodology, trace) do
    channels = methodology.questions |> Enum.map(&channel_for_type(&1.type)) |> Enum.uniq()
    zeroes = Map.new(methodology.dimensions, &{&1, 0})
    initial = Map.new(channels, &{&1, zeroes})

    Enum.reduce(trace, initial, fn entry, totals ->
      channel_totals = Map.fetch!(totals, entry.channel)

      updated =
        Map.new(channel_totals, fn {dimension, total} ->
          {dimension, total + Map.fetch!(entry.weighted_contributions, dimension)}
        end)

      Map.put(totals, entry.channel, updated)
    end)
  end

  defp channel_for_type(:forced_choice), do: :forced_choice
  defp channel_for_type(:agreement_scale), do: :agreement_scale
end
