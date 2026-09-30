defmodule TemperamentEngine.PresentationGeneratorTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator

  test "shuffles all questions and each forced-choice response list independently" do
    methodology = Fixtures.mixed_methodology()
    assert {:ok, presentation} = Generator.generate(methodology, &Enum.reverse/1)

    assert presentation.question_order == Enum.map(Enum.reverse(methodology.questions), & &1.id)

    forced_choice = Enum.find(methodology.questions, &(&1.type == :forced_choice))
    agreement = Enum.find(methodology.questions, &(&1.type == :agreement_scale))

    assert presentation.response_order[forced_choice.id] ==
             forced_choice.responses |> Enum.reverse() |> Enum.map(& &1.id)

    assert presentation.response_order[agreement.id] == Enum.map(agreement.responses, & &1.id)
  end

  test "uses the OTP shuffle for a normal presentation and returns a valid permutation" do
    methodology = Fixtures.baseline_methodology()

    assert {:ok, presentation} = Generator.generate(methodology)
    assert :ok == Validator.validate(methodology, presentation)
  end

  test "rejects invalid methodology before generating a presentation" do
    invalid = %{Fixtures.baseline_methodology() | questions: []}

    assert {:error, errors} = Generator.generate(invalid)
    assert Enum.any?(errors, &(&1.code == :missing_questions))
  end
end
