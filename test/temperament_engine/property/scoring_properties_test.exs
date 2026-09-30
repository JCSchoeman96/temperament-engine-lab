defmodule TemperamentEngine.Property.ScoringPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Generators
  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response
  alias TemperamentEngine.Scoring.Ranking

  property "same methodology and semantic answers always produce the same result" do
    check all(choices <- Generators.baseline_choice_indices(25)) do
      methodology = Fixtures.baseline_methodology()
      answers = baseline_answers(methodology, choices)

      assert {:ok, first} = TemperamentEngine.score(methodology, answers)
      assert {:ok, second} = TemperamentEngine.score(methodology, answers)
      assert first == second
    end
  end

  property "equivalent answer maps constructed in different orders produce the same result" do
    check all(choices <- Generators.baseline_choice_indices(25)) do
      methodology = Fixtures.baseline_methodology()
      entries = Map.to_list(baseline_answers(methodology, choices))
      forward = Map.new(entries)
      reverse = Map.new(Enum.reverse(entries))

      assert forward == reverse
      assert {:ok, forward_result} = TemperamentEngine.score(methodology, forward)
      assert {:ok, reverse_result} = TemperamentEngine.score(methodology, reverse)
      assert forward_result == reverse_result
    end
  end

  property "unit-weight one-hot baseline scores equal an ordinary tally" do
    check all(choices <- Generators.baseline_choice_indices(25)) do
      methodology = Fixtures.baseline_methodology()
      answers = baseline_answers(methodology, choices)

      frequencies =
        choices |> Enum.map(&Enum.at(methodology.dimensions, &1)) |> Enum.frequencies()

      expected = Map.new(methodology.dimensions, &{&1, Map.get(frequencies, &1, 0)})

      assert {:ok, result} = TemperamentEngine.score(methodology, answers)
      assert result.channel_scores.forced_choice == expected
    end
  end

  property "trace weighted contributions sum exactly to every channel score" do
    check all(choices <- Generators.baseline_choice_indices(25)) do
      methodology = Fixtures.baseline_methodology()
      answers = baseline_answers(methodology, choices)
      assert {:ok, result} = TemperamentEngine.score(methodology, answers)

      traced_scores =
        Enum.reduce(result.trace, %{}, fn trace_entry, channels ->
          Map.update(
            channels,
            trace_entry.channel,
            trace_entry.weighted_contributions,
            fn totals ->
              Map.new(totals, fn {dimension, total} ->
                {dimension, total + Map.fetch!(trace_entry.weighted_contributions, dimension)}
              end)
            end
          )
        end)

      assert traced_scores == result.channel_scores
    end
  end

  property "trace totals remain channel-specific for mixed evidence" do
    check all(forced_choice_index <- integer(0..3), agreement_index <- integer(0..3)) do
      methodology = Fixtures.mixed_methodology()
      [forced_choice, agreement] = methodology.questions

      answers = %{
        forced_choice.id => Enum.at(forced_choice.responses, forced_choice_index).id,
        agreement.id => Enum.at(agreement.responses, agreement_index).id
      }

      assert {:ok, result} = TemperamentEngine.score(methodology, answers)

      traced_scores =
        Enum.reduce(result.trace, %{}, fn trace_entry, channels ->
          Map.update(
            channels,
            trace_entry.channel,
            trace_entry.weighted_contributions,
            fn totals ->
              Map.new(totals, fn {dimension, total} ->
                {dimension, total + Map.fetch!(trace_entry.weighted_contributions, dimension)}
              end)
            end
          )
        end)

      assert traced_scores == result.channel_scores
    end
  end

  property "common positive scaling preserves ranking groups and tie structure" do
    check all(choices <- list_of(integer(0..2), length: 2), scale <- Generators.positive_scales()) do
      methodology = Fixtures.weighted_methodology()

      answers =
        methodology.questions
        |> Enum.zip(choices)
        |> Map.new(fn {question, index} ->
          {question.id, Enum.at(question.responses, index).id}
        end)

      scaled = %{
        methodology
        | questions: Enum.map(methodology.questions, &%{&1 | weight: &1.weight * scale})
      }

      assert {:ok, original_result} = TemperamentEngine.score(methodology, answers)
      assert {:ok, scaled_result} = TemperamentEngine.score(scaled, answers)
      assert original_result.ranking == scaled_result.ranking
      assert original_result.top_tie? == scaled_result.top_tie?
    end
  end

  property "an explicit zero response contribution has no score effect" do
    check all(
            weight <- Generators.positive_scales(),
            contribution <- Generators.positive_contributions()
          ) do
      dimensions = Fixtures.dimensions()
      omitted = zero_comparison_methodology(dimensions, weight, contribution, false)
      explicit = zero_comparison_methodology(dimensions, weight, contribution, true)
      answers = %{"zero_question" => "selected"}

      assert {:ok, omitted_result} = TemperamentEngine.score(omitted, answers)
      assert {:ok, explicit_result} = TemperamentEngine.score(explicit, answers)
      assert omitted_result.channel_scores == explicit_result.channel_scores
      assert omitted_result.ranking == explicit_result.ranking
    end
  end

  property "equal integer scores stay in an explicit ranking tie group" do
    check all(score <- Generators.contributions()) do
      dimensions = Fixtures.dimensions()

      methodology = %Methodology{
        id: "synthetic_property_tie",
        version: "1.0.0-research",
        dimensions: dimensions,
        questions: [
          %Question{
            id: "tie_question",
            type: :forced_choice,
            weight: 1,
            responses: [
              %Response{
                id: "selected",
                contributions: %{"yellow" => score, "red" => score}
              }
            ]
          }
        ],
        ranking_source: {:channel, :forced_choice}
      }

      assert {:ok, result} = TemperamentEngine.score(methodology, %{"tie_question" => "selected"})
      assert result.ranking_scores["yellow"] == result.ranking_scores["red"]
      assert Ranking.top_tie?(result.ranking)
    end
  end

  defp baseline_answers(methodology, choices) do
    methodology.questions
    |> Enum.zip(choices)
    |> Map.new(fn {question, index} ->
      {question.id, Enum.at(question.responses, index).id}
    end)
  end

  defp zero_comparison_methodology(dimensions, weight, contribution, explicit_zero?) do
    contributions =
      if explicit_zero?,
        do: %{"yellow" => contribution, "red" => 0},
        else: %{"yellow" => contribution}

    %Methodology{
      id: "synthetic_zero",
      version: "1.0.0-research",
      dimensions: dimensions,
      questions: [
        %Question{
          id: "zero_question",
          type: :forced_choice,
          weight: weight,
          responses: [%Response{id: "selected", contributions: contributions}]
        }
      ],
      ranking_source: {:channel, :forced_choice}
    }
  end
end
