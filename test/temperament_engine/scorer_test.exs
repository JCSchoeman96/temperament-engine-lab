defmodule TemperamentEngine.ScorerTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Scoring.Scorer

  test "applies question weights and response vectors with integer arithmetic" do
    methodology = Fixtures.weighted_methodology()

    answers = %{
      "weighted_001" => "weighted_001_a",
      "weighted_002" => "weighted_002_a"
    }

    assert {:ok, result} = Scorer.score(methodology, answers)

    assert result.channel_scores == %{
             forced_choice: %{"yellow" => 4, "red" => 8, "green" => 0, "blue" => 0}
           }

    assert result.ranking_scores == %{"yellow" => 4, "red" => 8, "green" => 0, "blue" => 0}
    assert result.ranking == [["red"], ["yellow"], ["green", "blue"]]
    assert result.top_tie? == false

    assert Enum.map(result.trace, & &1.question_id) == Enum.map(methodology.questions, & &1.id)

    assert Enum.at(result.trace, 0).raw_contributions == %{
             "yellow" => 2,
             "red" => 1,
             "green" => 0,
             "blue" => 0
           }

    assert Enum.at(result.trace, 0).weighted_contributions == %{
             "yellow" => 4,
             "red" => 2,
             "green" => 0,
             "blue" => 0
           }
  end

  test "returns independent mixed channels and no ranking when ranking is disabled" do
    methodology = Fixtures.mixed_methodology()
    answers = %{"fc_mixed_001" => "fc_mixed_001_a", "ag_synthetic_01" => "ag_synthetic_01_agree"}

    assert {:ok, result} = Scorer.score(methodology, answers)

    assert result.channel_scores == %{
             forced_choice: %{"yellow" => 1, "red" => 0, "green" => 0, "blue" => 0},
             agreement_scale: %{"yellow" => 0, "red" => 0, "green" => 0, "blue" => 2}
           }

    assert result.ranking_scores == nil
    assert result.ranking == nil
    assert result.top_tie? == nil
    assert Enum.map(result.trace, & &1.channel) == [:forced_choice, :agreement_scale]
  end

  test "preserves exact top and lower-rank ties" do
    methodology = Fixtures.ranking_methodology()
    answers = Map.new(methodology.questions, &{&1.id, "#{&1.id}_selected"})

    assert {:ok, result} = Scorer.score(methodology, answers)
    assert result.ranking_scores == %{"yellow" => 2, "red" => 2, "green" => 1, "blue" => 1}
    assert result.ranking == [["yellow", "red"], ["green", "blue"]]
    assert result.top_tie? == true
  end

  test "rejects missing, extra, unknown and wrong-question answers" do
    methodology = Fixtures.mixed_methodology()
    complete = Fixtures.answers_for(methodology)

    assert :missing_answer in codes(
             Scorer.score(methodology, Map.delete(complete, "fc_mixed_001"))
           )

    assert :unknown_question in codes(
             Scorer.score(methodology, Map.put(complete, "extra", "answer"))
           )

    unknown_response = Map.put(complete, "fc_mixed_001", "missing_response")
    assert :unknown_response in codes(Scorer.score(methodology, unknown_response))

    wrong_response = Map.put(complete, "fc_mixed_001", "ag_synthetic_01_agree")

    assert :response_belongs_to_wrong_question in codes(Scorer.score(methodology, wrong_response))
  end

  test "rejects malformed methodology and answer values before scoring" do
    methodology = %{Fixtures.weighted_methodology() | dimensions: []}

    assert :missing_dimensions in codes(Scorer.score(methodology, %{}))
    assert :invalid_answers in codes(Scorer.score(Fixtures.weighted_methodology(), :not_a_map))
  end

  test "records sparse contribution definitions as zero-filled trace vectors" do
    methodology = Fixtures.weighted_methodology()
    answers = %{"weighted_001" => "weighted_001_c", "weighted_002" => "weighted_002_c"}

    assert {:ok, result} = Scorer.score(methodology, answers)

    assert result.channel_scores.forced_choice == %{
             "yellow" => 0,
             "red" => 0,
             "green" => 0,
             "blue" => 0
           }

    assert Enum.all?(
             result.trace,
             &(&1.raw_contributions == %{"yellow" => 0, "red" => 0, "green" => 0, "blue" => 0})
           )
  end

  test "metadata and presentation permutations do not change semantic scoring" do
    methodology = Fixtures.baseline_methodology()

    changed_metadata = %{
      methodology
      | questions: Enum.map(methodology.questions, &%{&1 | metadata: %{research_note: "changed"}})
    }

    answers = Fixtures.answers_for(methodology, 2)
    assert {:ok, reversed_presentation} = Generator.generate(methodology, &Enum.reverse/1)
    assert {:ok, declared_presentation} = Generator.generate(methodology, &Function.identity/1)
    refute reversed_presentation.question_order == declared_presentation.question_order

    assert {:ok, original_result} = Scorer.score(methodology, answers)
    assert {:ok, metadata_result} = Scorer.score(changed_metadata, answers)
    assert original_result == metadata_result
  end

  defp codes({:error, errors}), do: Enum.map(errors, & &1.code)
  defp codes({:ok, _result}), do: []
end
