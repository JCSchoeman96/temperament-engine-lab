defmodule TemperamentEngine.Property.PresentationPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator

  property "generated question order is an exact permutation of methodology questions" do
    check all(_iteration <- integer(0..1000)) do
      methodology = Fixtures.baseline_methodology()
      assert {:ok, presentation} = Generator.generate(methodology)

      assert length(presentation.question_order) == length(methodology.questions)

      assert MapSet.new(presentation.question_order) ==
               MapSet.new(Enum.map(methodology.questions, & &1.id))

      assert :ok == Validator.validate(methodology, presentation)
    end
  end

  property "each generated forced-choice response order is an exact permutation" do
    check all(_iteration <- integer(0..1000)) do
      methodology = Fixtures.baseline_methodology()
      assert {:ok, presentation} = Generator.generate(methodology)

      for question <- methodology.questions do
        assert MapSet.new(presentation.response_order[question.id]) ==
                 MapSet.new(Enum.map(question.responses, & &1.id))

        assert length(presentation.response_order[question.id]) == length(question.responses)
      end
    end
  end

  property "generated agreement responses retain their declared canonical order" do
    check all(_iteration <- integer(0..1000)) do
      methodology = Fixtures.mixed_methodology()
      agreement = Enum.find(methodology.questions, &(&1.type == :agreement_scale))
      expected_order = Enum.map(agreement.responses, & &1.id)

      assert {:ok, presentation} = Generator.generate(methodology)
      assert presentation.response_order[agreement.id] == expected_order
    end
  end
end
