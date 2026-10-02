defmodule TemperamentEngine.MethodologyValidatorTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Methodology.Validator
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response

  test "accepts baseline, mixed and weighted synthetic methodologies" do
    assert :ok == Validator.validate(Fixtures.baseline_methodology())
    assert :ok == Validator.validate(Fixtures.mixed_methodology())
    assert :ok == Validator.validate(Fixtures.weighted_methodology())
  end

  test "accepts an empty contribution map and metadata that does not affect validation" do
    methodology = Fixtures.weighted_methodology()
    [question | remaining] = methodology.questions
    [response | other_responses] = question.responses

    changed = %{
      methodology
      | questions: [
          %{
            question
            | metadata: %{research_note: "synthetic"},
              responses: [%{response | contributions: %{}} | other_responses]
          }
          | remaining
        ]
    }

    assert :ok == Validator.validate(changed)
  end

  test "rejects malformed dimensions, metadata and response entries" do
    methodology = Fixtures.baseline_methodology()
    [question | remaining] = methodology.questions

    invalid = %{
      methodology
      | dimensions: :not_a_list,
        questions: [%{question | metadata: nil, responses: [:not_a_response]} | remaining]
    }

    codes = errors_for(invalid) |> Enum.map(& &1.code)

    assert :invalid_dimensions in codes
    assert :invalid_metadata in codes
    assert :invalid_response in codes
  end

  test "reports invalid methodology identity, dimensions and question collection" do
    methodology = Fixtures.baseline_methodology()

    invalid = %{
      methodology
      | id: " ",
        version: "",
        dimensions: ["yellow", "yellow"],
        questions: :not_a_list
    }

    errors = errors_for(invalid)
    codes = Enum.map(errors, & &1.code)

    assert :invalid_identifier in codes
    assert :duplicate_dimension in codes
    assert :invalid_questions in codes
    assert Enum.any?(errors, &(&1.path == [:id]))
  end

  test "accepts conservative ASCII machine identifiers" do
    methodology = Fixtures.baseline_methodology()
    [question | remaining] = methodology.questions
    [response | other_responses] = question.responses

    valid = %{
      methodology
      | id: "research.v1-1",
        version: "v1_0",
        questions: [
          %{
            question
            | id: "question.001-a",
              responses: [%{response | id: "option_1.a"} | other_responses]
          }
          | remaining
        ]
    }

    assert :ok == Validator.validate(valid)
  end

  test "rejects whitespace, control characters and non-ASCII machine identifiers" do
    methodology = Fixtures.baseline_methodology()
    [question | remaining] = methodology.questions
    [response | other_responses] = question.responses

    invalid_methodologies = [
      %{methodology | id: "research id"},
      %{methodology | version: "version\n1"},
      %{methodology | dimensions: ["jaune🟡" | tl(methodology.dimensions)]},
      %{
        methodology
        | questions: [%{question | id: "question\u00a0001"} | remaining]
      },
      %{
        methodology
        | questions: [
            %{question | responses: [%{response | id: "option\u200b1"} | other_responses]}
            | remaining
          ]
      }
    ]

    assert Enum.all?(invalid_methodologies, fn invalid ->
             :invalid_identifier in (errors_for(invalid) |> Enum.map(& &1.code))
           end)
  end

  test "rejects duplicate questions, unsupported types and invalid weights" do
    methodology = Fixtures.baseline_methodology()
    [first, second | rest] = methodology.questions

    invalid = %{
      methodology
      | questions: [first, %{second | id: first.id, type: :unknown, weight: 0} | rest]
    }

    codes = errors_for(invalid) |> Enum.map(& &1.code)

    assert :duplicate_question in codes
    assert :unsupported_question_type in codes
    assert :invalid_question_weight in codes
  end

  test "rejects empty responses and duplicate or blank response identifiers" do
    methodology = Fixtures.baseline_methodology()
    [question | rest] = methodology.questions
    [first, second | responses] = question.responses

    empty = %{methodology | questions: [%{question | responses: []} | rest]}

    duplicate = %{
      methodology
      | questions: [%{question | responses: [first, %{second | id: first.id} | responses]} | rest]
    }

    blank = %{
      methodology
      | questions: [%{question | responses: [%{first | id: ""} | [second | responses]]} | rest]
    }

    assert :missing_responses in (errors_for(empty) |> Enum.map(& &1.code))
    assert :duplicate_response in (errors_for(duplicate) |> Enum.map(& &1.code))
    assert :invalid_identifier in (errors_for(blank) |> Enum.map(& &1.code))
  end

  test "rejects undeclared dimensions and non-integer or negative contributions" do
    methodology = Fixtures.baseline_methodology()
    [question | rest] = methodology.questions
    [response | responses] = question.responses

    invalid = %{
      methodology
      | questions: [
          %{
            question
            | responses: [
                %{response | contributions: %{"unknown" => 1, "yellow" => -1, "red" => 1.5}}
                | responses
              ]
          }
          | rest
        ]
    }

    codes = errors_for(invalid) |> Enum.map(& &1.code)

    assert :undeclared_dimension in codes
    assert :invalid_contribution in codes
    assert Enum.count(codes, &(&1 == :invalid_contribution)) == 2
  end

  test "fails closed for an unavailable or unsupported ranking source" do
    methodology = Fixtures.mixed_methodology()

    agreement_only =
      %{
        methodology
        | questions: Enum.filter(methodology.questions, &(&1.type == :agreement_scale))
      }

    unavailable = %{agreement_only | ranking_source: {:channel, :forced_choice}}
    unsupported = %{methodology | ranking_source: {:channel, :combined}}

    assert :ranking_channel_unavailable in (errors_for(unavailable) |> Enum.map(& &1.code))
    assert :unsupported_ranking_source in (errors_for(unsupported) |> Enum.map(& &1.code))
  end

  test "returns machine-readable errors instead of raising on malformed nested values" do
    assert {:error, [%{code: :invalid_methodology}]} = Validator.validate(:not_a_methodology)

    methodology = Fixtures.baseline_methodology()

    malformed = %{
      methodology
      | questions: [
          %Question{
            id: "q",
            type: :forced_choice,
            weight: 1,
            responses: [%Response{id: "r", contributions: :invalid}]
          }
        ]
    }

    assert {:error, errors} = Validator.validate(malformed)
    assert Enum.any?(errors, &(&1.code == :invalid_contributions))
  end

  test "only none or the forced-choice channel is a supported ranking source" do
    methodology = Fixtures.baseline_methodology()

    assert :ok == Validator.validate(%{methodology | ranking_source: :none})

    assert :unsupported_ranking_source in (errors_for(%{methodology | ranking_source: :unknown})
                                           |> Enum.map(& &1.code))
  end

  defp errors_for(%Methodology{} = methodology) do
    assert {:error, errors} = Validator.validate(methodology)
    errors
  end
end
