defmodule TemperamentEngine.PresentationValidatorTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Presentation
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator

  test "accepts an exact question and response permutation" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)
    assert :ok == Validator.validate(methodology, presentation)
  end

  test "rejects methodology identity and version mismatches" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)

    wrong_identity = %{presentation | methodology_id: "other"}
    wrong_version = %{presentation | methodology_version: "other"}

    assert :methodology_identity_mismatch in codes(
             Validator.validate(methodology, wrong_identity)
           )

    assert :methodology_version_mismatch in codes(Validator.validate(methodology, wrong_version))
  end

  test "rejects missing, duplicate and unknown questions" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)
    [first, _second] = presentation.question_order

    missing = %{presentation | question_order: [first]}
    duplicate = %{presentation | question_order: [first, first]}
    unknown = %{presentation | question_order: [first, "unknown_question"]}

    assert :missing_question in codes(Validator.validate(methodology, missing))
    assert :duplicate_question in codes(Validator.validate(methodology, duplicate))
    assert :unknown_question in codes(Validator.validate(methodology, unknown))
  end

  test "rejects missing, duplicate and unknown responses for a question" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)
    question = Enum.find(methodology.questions, &(&1.type == :forced_choice))
    [first | rest] = presentation.response_order[question.id]

    missing = %{
      presentation
      | response_order: Map.put(presentation.response_order, question.id, [first])
    }

    duplicate = %{
      presentation
      | response_order: Map.put(presentation.response_order, question.id, [first, first | rest])
    }

    unknown = %{
      presentation
      | response_order:
          Map.put(presentation.response_order, question.id, ["unknown_response" | rest])
    }

    assert :missing_response in codes(Validator.validate(methodology, missing))
    assert :duplicate_response in codes(Validator.validate(methodology, duplicate))
    assert :unknown_response in codes(Validator.validate(methodology, unknown))
  end

  test "rejects a response mapped to another question and unknown response-order question IDs" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)
    [forced_choice, agreement] = methodology.questions
    foreign_response = hd(presentation.response_order[agreement.id])

    wrong_question = %{
      presentation
      | response_order: Map.put(presentation.response_order, forced_choice.id, [foreign_response])
    }

    unknown_question = %{
      presentation
      | response_order:
          Map.put(presentation.response_order, "unknown_question", ["unknown_response"])
    }

    missing_mapping = %{
      presentation
      | response_order: Map.delete(presentation.response_order, agreement.id)
    }

    assert :response_belongs_to_wrong_question in codes(
             Validator.validate(methodology, wrong_question)
           )

    assert :unknown_question in codes(Validator.validate(methodology, unknown_question))
    assert :missing_response_order in codes(Validator.validate(methodology, missing_mapping))
  end

  test "rejects an agreement response order that differs from the declared scale order" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)
    agreement = Enum.find(methodology.questions, &(&1.type == :agreement_scale))

    changed = %{
      presentation
      | response_order:
          Map.put(
            presentation.response_order,
            agreement.id,
            Enum.reverse(presentation.response_order[agreement.id])
          )
    }

    assert :agreement_response_order_changed in codes(Validator.validate(methodology, changed))
  end

  test "rejects malformed presentation values without raising" do
    methodology = Fixtures.mixed_methodology()

    assert :invalid_presentation in codes(Validator.validate(methodology, :invalid))

    malformed = %Presentation{
      methodology_id: methodology.id,
      methodology_version: methodology.version,
      question_order: :invalid,
      response_order: :invalid
    }

    assert :invalid_question_order in codes(Validator.validate(methodology, malformed))
    assert :invalid_response_order in codes(Validator.validate(methodology, malformed))
  end

  defp codes({:error, errors}), do: Enum.map(errors, & &1.code)
  defp codes(:ok), do: []
end
