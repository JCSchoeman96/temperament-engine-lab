defmodule TemperamentEngine.MethodologyAnalyzerTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Methodology.Analyzer
  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response
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
             },
             maximum_single_question_swing_by_dimension: %{
               "yellow" => 4,
               "red" => 6,
               "green" => 3,
               "blue" => 2
             }
           }

    assert Map.keys(Map.from_struct(analysis)) |> Enum.sort() ==
             [:by_channel, :by_question, :warnings]
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

  test "reports four one-hot responses as four distinct scoring vectors" do
    question =
      question("one_hot", [
        response("yellow_response", %{"yellow" => 1}),
        response("red_response", %{"red" => 1}),
        response("green_response", %{"green" => 1}),
        response("blue_response", %{"blue" => 1})
      ])

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))
    diagnostic = analysis.by_question["one_hot"]

    assert diagnostic.channel == :forced_choice
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

  test "groups responses with identical scoring vectors in declaration order" do
    question =
      question("duplicates", [
        response("response_a", %{"yellow" => 1}),
        response("response_b", %{"yellow" => 1, "red" => 0}),
        response("response_c", %{"red" => 1})
      ])

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))
    diagnostic = analysis.by_question["duplicates"]

    assert diagnostic.response_count == 3
    assert diagnostic.distinct_scoring_vector_count == 2
    assert diagnostic.duplicate_scoring_vector_groups == [["response_a", "response_b"]]
    refute diagnostic.non_discriminating?
  end

  test "marks a question non-discriminating when every response has the same vector" do
    question =
      question("same_vector", [
        response("response_a", %{"yellow" => 1}),
        response("response_b", %{"yellow" => 1}),
        response("response_c", %{"yellow" => 1})
      ])

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))
    diagnostic = analysis.by_question["same_vector"]

    assert diagnostic.distinct_scoring_vector_count == 1

    assert diagnostic.duplicate_scoring_vector_groups == [
             ["response_a", "response_b", "response_c"]
           ]

    assert diagnostic.non_discriminating?
  end

  test "a question with one valid response is scoring-non-discriminating" do
    question = question("single_response", [response("only_response", %{"yellow" => 1})])

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))
    diagnostic = analysis.by_question["single_response"]

    assert diagnostic.response_count == 1
    assert diagnostic.distinct_scoring_vector_count == 1
    assert diagnostic.duplicate_scoring_vector_groups == []
    assert diagnostic.non_discriminating?
  end

  test "treats sparse and explicit zero scoring vectors identically" do
    sparse =
      methodology([
        question("zero_equivalence", [
          response("response_a", %{"yellow" => 1}),
          response("response_b", %{"yellow" => 1})
        ])
      ])

    explicit_zeroes = %{
      sparse
      | questions:
          Enum.map(sparse.questions, fn question ->
            responses =
              Enum.map(question.responses, fn response ->
                zeroes = Map.new(sparse.dimensions, &{&1, 0})
                %{response | contributions: Map.merge(zeroes, response.contributions)}
              end)

            %{question | responses: responses}
          end)
    }

    assert {:ok, sparse_analysis} = Analyzer.analyze(sparse)
    assert {:ok, explicit_analysis} = Analyzer.analyze(explicit_zeroes)
    assert explicit_analysis == sparse_analysis
  end

  test "includes question weight in marginal swing" do
    question =
      question(
        "weighted_swing",
        [
          response("response_a", %{"yellow" => 0}),
          response("response_b", %{"yellow" => 2})
        ],
        weight: 3
      )

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))
    diagnostic = analysis.by_question["weighted_swing"]

    assert diagnostic.marginal_minimum_by_dimension["yellow"] == 0
    assert diagnostic.marginal_maximum_by_dimension["yellow"] == 6
    assert diagnostic.marginal_swing_by_dimension["yellow"] == 6
  end

  test "reports zero score opportunity at the exact channel and dimension path" do
    question = question("no_red", [response("yellow_response", %{"yellow" => 1})])

    assert {:ok, analysis} = Analyzer.analyze(methodology([question]))

    assert Enum.any?(analysis.warnings, fn warning ->
             warning.code == :zero_score_opportunity and
               warning.path ==
                 [:by_channel, :forced_choice, :marginal_maximum_by_dimension, "red"]
           end)
  end

  test "does not report zero channel opportunity when another question can score the dimension" do
    questions = [
      question("red_opportunity", [
        response("red_response", %{"red" => 1}),
        response("zero_response", %{})
      ]),
      question("no_red_swing", [
        response("first_response", %{"yellow" => 1}),
        response("second_response", %{"yellow" => 0})
      ])
    ]

    assert {:ok, analysis} = Analyzer.analyze(methodology(questions))

    refute Enum.any?(analysis.warnings, fn warning ->
             warning.code == :zero_score_opportunity and
               warning.path ==
                 [:by_channel, :forced_choice, :marginal_maximum_by_dimension, "red"]
           end)
  end

  test "reports the largest single-question swing within each channel" do
    questions = [
      question("small_swing", [
        response("response_a", %{"yellow" => 0}),
        response("response_b", %{"yellow" => 1})
      ]),
      question(
        "large_swing",
        [
          response("response_a", %{"yellow" => 0}),
          response("response_b", %{"yellow" => 2})
        ],
        weight: 3
      )
    ]

    assert {:ok, analysis} = Analyzer.analyze(methodology(questions))

    assert analysis.by_channel.forced_choice.maximum_single_question_swing_by_dimension == %{
             "yellow" => 6,
             "red" => 0,
             "green" => 0,
             "blue" => 0
           }
  end

  defp response(id, contributions), do: %Response{id: id, contributions: contributions}

  defp question(id, responses, options \\ []) do
    %Question{
      id: id,
      type: Keyword.get(options, :type, :forced_choice),
      weight: Keyword.get(options, :weight, 1),
      responses: responses
    }
  end

  defp methodology(questions) do
    %Methodology{
      id: "synthetic_analyzer",
      version: "1.0.0-research",
      dimensions: ["yellow", "red", "green", "blue"],
      questions: questions,
      ranking_source: :none
    }
  end
end
