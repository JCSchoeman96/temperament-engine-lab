defmodule TemperamentEngine.BaselineCompatibilityTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Methodology.Analyzer

  test "baseline fixture is 25 synthetic one-hot forced-choice questions at weight one" do
    methodology = Fixtures.baseline_methodology()

    assert length(methodology.questions) == 25
    assert methodology.dimensions == ["yellow", "red", "green", "blue"]
    assert Enum.all?(methodology.questions, &(&1.type == :forced_choice and &1.weight == 1))
    assert Enum.all?(methodology.questions, &(length(&1.responses) == 4))

    for question <- methodology.questions do
      assert Enum.map(question.responses, & &1.contributions) == [
               %{"yellow" => 1},
               %{"red" => 1},
               %{"green" => 1},
               %{"blue" => 1}
             ]
    end
  end

  test "weighted engine exactly reproduces ordinary count-per-dimension scoring" do
    methodology = Fixtures.baseline_methodology()
    selected_positions = Enum.map(1..25, &rem(&1 * 3 + 1, 4))

    answers =
      methodology.questions
      |> Enum.zip(selected_positions)
      |> Map.new(fn {question, position} ->
        {question.id, Enum.at(question.responses, position).id}
      end)

    expected =
      selected_positions
      |> Enum.map(&Enum.at(methodology.dimensions, &1))
      |> Enum.frequencies()

    expected_scores = Map.new(methodology.dimensions, &{&1, Map.get(expected, &1, 0)})

    assert {:ok, result} = TemperamentEngine.score(methodology, answers)
    assert result.ranking_scores == expected_scores
    assert result.channel_scores == %{forced_choice: expected_scores}
    assert Enum.sum(Map.values(result.ranking_scores)) == 25
  end

  test "baseline analyzer reports four scoring vectors and one point of question swing" do
    methodology = Fixtures.baseline_methodology()

    assert {:ok, analysis} = Analyzer.analyze(methodology)

    for question <- methodology.questions do
      diagnostic = analysis.by_question[question.id]

      assert question.weight == 1
      assert length(question.responses) == 4
      assert diagnostic.response_count == 4
      assert diagnostic.distinct_scoring_vector_count == 4
      assert diagnostic.duplicate_scoring_vector_groups == []
      refute diagnostic.non_discriminating?

      assert diagnostic.marginal_swing_by_dimension == %{
               "yellow" => 1,
               "red" => 1,
               "green" => 1,
               "blue" => 1
             }
    end

    assert analysis.by_channel.forced_choice.maximum_single_question_swing_by_dimension == %{
             "yellow" => 1,
             "red" => 1,
             "green" => 1,
             "blue" => 1
           }
  end
end
