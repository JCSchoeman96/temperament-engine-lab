defmodule TemperamentEngine.Property.AnalyzerPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TemperamentEngine.Generators
  alias TemperamentEngine.Methodology.Analyzer

  property "generated question ranges contain each weighted response and equal their extrema" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      assert {:ok, analysis} = Analyzer.analyze(methodology)

      for question <- methodology.questions,
          dimension <- methodology.dimensions do
        diagnostic = Map.fetch!(analysis.by_question, question.id)

        values =
          Enum.map(question.responses, fn response ->
            question.weight * Map.get(response.contributions, dimension, 0)
          end)

        minimum = Enum.min(values)
        maximum = Enum.max(values)

        assert diagnostic.marginal_minimum_by_dimension[dimension] == minimum
        assert diagnostic.marginal_maximum_by_dimension[dimension] == maximum
        assert diagnostic.marginal_swing_by_dimension[dimension] == maximum - minimum

        assert Enum.all?(values, fn value ->
                 diagnostic.marginal_minimum_by_dimension[dimension] <= value and
                   value <= diagnostic.marginal_maximum_by_dimension[dimension]
               end)
      end
    end
  end

  property "channel single-question swings equal the maximum question swing" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      assert {:ok, analysis} = Analyzer.analyze(methodology)

      for {channel, channel_analysis} <- analysis.by_channel,
          dimension <- methodology.dimensions do
        expected_maximum =
          methodology.questions
          |> Enum.filter(&(channel_for_type(&1.type) == channel))
          |> Enum.map(fn question ->
            analysis.by_question[question.id].marginal_swing_by_dimension[dimension]
          end)
          |> Enum.max()

        assert channel_analysis.maximum_single_question_swing_by_dimension[dimension] ==
                 expected_maximum
      end
    end
  end

  property "question declaration order does not change generated diagnostics" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      reordered = %{methodology | questions: Enum.reverse(methodology.questions)}

      assert {:ok, original_analysis} = Analyzer.analyze(methodology)
      assert {:ok, reordered_analysis} = Analyzer.analyze(reordered)
      assert reordered_analysis == original_analysis
    end
  end

  property "response declaration reordering preserves diagnostic values and duplicate membership" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      reordered = %{
        methodology
        | questions:
            Enum.map(methodology.questions, fn question ->
              %{question | responses: Enum.reverse(question.responses)}
            end)
      }

      assert {:ok, original_analysis} = Analyzer.analyze(methodology)
      assert {:ok, reordered_analysis} = Analyzer.analyze(reordered)
      assert reordered_analysis.by_channel == original_analysis.by_channel
      assert reordered_analysis.warnings == original_analysis.warnings

      for question <- methodology.questions do
        original = original_analysis.by_question[question.id]
        reordered_question = reordered_analysis.by_question[question.id]

        assert reordered_question.marginal_minimum_by_dimension ==
                 original.marginal_minimum_by_dimension

        assert reordered_question.marginal_maximum_by_dimension ==
                 original.marginal_maximum_by_dimension

        assert reordered_question.marginal_swing_by_dimension ==
                 original.marginal_swing_by_dimension

        assert reordered_question.distinct_scoring_vector_count ==
                 original.distinct_scoring_vector_count

        assert reordered_question.non_discriminating? == original.non_discriminating?

        assert duplicate_memberships(reordered_question.duplicate_scoring_vector_groups) ==
                 duplicate_memberships(original.duplicate_scoring_vector_groups)
      end
    end
  end

  property "discrimination and duplicate groups match canonical complete weighted vectors" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      assert {:ok, analysis} = Analyzer.analyze(methodology)

      for question <- methodology.questions do
        diagnostic = analysis.by_question[question.id]

        vectors =
          Map.new(question.responses, fn response ->
            {response.id, canonical_vector(response, question.weight, methodology.dimensions)}
          end)

        distinct_vector_count = vectors |> Map.values() |> MapSet.new() |> MapSet.size()
        assert diagnostic.distinct_scoring_vector_count == distinct_vector_count
        assert diagnostic.non_discriminating? == (distinct_vector_count == 1)

        expected_groups =
          question.responses
          |> Enum.group_by(&Map.fetch!(vectors, &1.id), & &1.id)
          |> Map.values()
          |> Enum.filter(&(length(&1) > 1))
          |> duplicate_memberships()

        actual_groups = duplicate_memberships(diagnostic.duplicate_scoring_vector_groups)
        assert actual_groups == expected_groups

        grouped_response_ids = Enum.flat_map(diagnostic.duplicate_scoring_vector_groups, & &1)
        assert length(grouped_response_ids) == length(Enum.uniq(grouped_response_ids))

        Enum.each(diagnostic.duplicate_scoring_vector_groups, fn group ->
          assert group |> Enum.map(&Map.fetch!(vectors, &1)) |> Enum.uniq() |> length() == 1
        end)
      end
    end
  end

  property "explicit and omitted zeroes produce identical generated diagnostics" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
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

      assert {:ok, original_analysis} = Analyzer.analyze(methodology)
      assert {:ok, explicit_analysis} = Analyzer.analyze(explicit_zeroes)
      assert explicit_analysis == original_analysis
    end
  end

  property "zero-opportunity warnings exactly identify zero channel maxima" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      assert {:ok, analysis} = Analyzer.analyze(methodology)

      expected_paths =
        for {channel, channel_analysis} <- analysis.by_channel,
            dimension <- methodology.dimensions,
            channel_analysis.marginal_maximum_by_dimension[dimension] == 0 do
          [:by_channel, channel, :marginal_maximum_by_dimension, dimension]
        end

      actual_paths =
        analysis.warnings
        |> Enum.filter(&(&1.code == :zero_score_opportunity))
        |> Enum.map(& &1.path)

      assert Enum.sort(actual_paths) == Enum.sort(expected_paths)
    end
  end

  defp canonical_vector(response, weight, dimensions) do
    Map.new(dimensions, fn dimension ->
      {dimension, weight * Map.get(response.contributions, dimension, 0)}
    end)
  end

  defp duplicate_memberships(groups) do
    groups
    |> Enum.map(&Enum.sort/1)
    |> Enum.sort()
  end

  defp channel_for_type(:forced_choice), do: :forced_choice
  defp channel_for_type(:agreement_scale), do: :agreement_scale
end
