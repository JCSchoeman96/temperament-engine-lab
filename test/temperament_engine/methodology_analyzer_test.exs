defmodule TemperamentEngine.MethodologyAnalyzerTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Methodology.Analyzer
  alias TemperamentEngine.Scoring.Scorer

  test "calculates weighted marginal ranges within each channel" do
    assert {:ok, analysis} = Analyzer.analyze(Fixtures.weighted_methodology())

    assert analysis.by_channel.forced_choice == %{
             marginal_minimum_by_dimension: %{
               "yellow" => 0,
               "red" => 0,
               "green" => 0,
               "blue" => 0
             },
             marginal_maximum_by_dimension: %{
               "yellow" => 4,
               "red" => 8,
               "green" => 3,
               "blue" => 2
             }
           }

    assert Map.keys(Map.from_struct(analysis)) |> Enum.sort() == [:by_channel, :warnings]
  end

  test "keeps mixed-channel opportunity separate and warns within channel scope" do
    assert {:ok, analysis} = Analyzer.analyze(Fixtures.mixed_methodology())

    assert analysis.by_channel.forced_choice.marginal_maximum_by_dimension == %{
             "yellow" => 1,
             "red" => 1,
             "green" => 1,
             "blue" => 1
           }

    assert analysis.by_channel.agreement_scale.marginal_maximum_by_dimension == %{
             "yellow" => 0,
             "red" => 0,
             "green" => 0,
             "blue" => 3
           }

    assert Enum.any?(analysis.warnings, fn warning ->
             warning.code == :unequal_maximum_opportunity and
               warning.path == [:by_channel, :agreement_scale, :marginal_maximum_by_dimension]
           end)

    refute Enum.any?(analysis.warnings, &(:all_channels in &1.path))
  end

  test "labels dimension extrema as marginal when no one answer realizes the full vector" do
    methodology = Fixtures.weighted_methodology()
    [question | remaining_questions] = methodology.questions

    responses = [
      %{hd(question.responses) | contributions: %{"yellow" => 1}},
      %{Enum.at(question.responses, 1) | contributions: %{"red" => 1}}
    ]

    changed = %{
      methodology
      | questions: [%{question | responses: responses} | remaining_questions]
    }

    assert {:ok, analysis} = Analyzer.analyze(changed)
    range = analysis.by_channel.forced_choice
    assert range.marginal_maximum_by_dimension["yellow"] == 2
    assert range.marginal_maximum_by_dimension["red"] == 8

    [second_question] = remaining_questions

    realized_scores =
      for first_response <- responses,
          second_response <- second_question.responses do
        answers = %{
          question.id => first_response.id,
          second_question.id => second_response.id
        }

        assert {:ok, result} = Scorer.score(changed, answers)
        result.channel_scores.forced_choice
      end

    refute Enum.any?(realized_scores, fn scores ->
             scores["yellow"] == range.marginal_maximum_by_dimension["yellow"] and
               scores["red"] == range.marginal_maximum_by_dimension["red"]
           end)
  end

  test "does not warn when maximum opportunities match across all dimensions" do
    assert {:ok, analysis} = Analyzer.analyze(Fixtures.baseline_methodology())
    assert analysis.warnings == []
  end

  test "rejects malformed methodology instead of analyzing partial data" do
    methodology = %{Fixtures.weighted_methodology() | dimensions: []}
    assert {:error, errors} = Analyzer.analyze(methodology)
    assert Enum.any?(errors, &(&1.code == :missing_dimensions))
  end
end
