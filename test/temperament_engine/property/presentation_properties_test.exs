defmodule TemperamentEngine.Property.PresentationPropertiesTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias TemperamentEngine.Generators
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator

  property "generated presentations validate and corrupted presentations fail" do
    check all(methodology <- Generators.methodologies(), max_runs: 300) do
      assert {:ok, presentation} = Generator.generate(methodology)
      assert :ok == Validator.validate(methodology, presentation)

      corrupted = %{presentation | question_order: []}
      assert {:error, errors} = Validator.validate(methodology, corrupted)
      assert Enum.any?(errors, &(&1.code == :missing_question))
    end
  end
end
