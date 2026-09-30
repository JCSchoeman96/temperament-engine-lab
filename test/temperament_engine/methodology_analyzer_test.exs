defmodule TemperamentEngine.MethodologyAnalyzerTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures
  alias TemperamentEngine.Methodology.Analyzer

  test "calculates weighted per-dimension opportunity from response definitions" do
    assert {:ok, analysis} = Analyzer.analyze(Fixtures.weighted_methodology())

    assert analysis.minimum_by_dimension == %{
             "yellow" => 0,
             "red" => 0,
             "green" => 0,
             "blue" => 0
           }

    assert analysis.maximum_by_dimension == %{
             "yellow" => 4,
             "red" => 8,
             "green" => 3,
             "blue" => 2
           }

    assert analysis.by_channel == %{
             forced_choice: %{
               minimum_by_dimension: analysis.minimum_by_dimension,
               maximum_by_dimension: analysis.maximum_by_dimension
             }
           }
  end

  test "keeps mixed-channel opportunity separate and warns about unequal ceilings" do
    assert {:ok, analysis} = Analyzer.analyze(Fixtures.mixed_methodology())

    assert analysis.minimum_by_dimension == %{
             "yellow" => 0,
             "red" => 0,
             "green" => 0,
             "blue" => 0
           }

    assert analysis.maximum_by_dimension == %{
             "yellow" => 1,
             "red" => 1,
             "green" => 1,
             "blue" => 4
           }

    assert analysis.by_channel.forced_choice.maximum_by_dimension == %{
             "yellow" => 1,
             "red" => 1,
             "green" => 1,
             "blue" => 1
           }

    assert analysis.by_channel.agreement_scale.maximum_by_dimension == %{
             "yellow" => 0,
             "red" => 0,
             "green" => 0,
             "blue" => 3
           }

    assert Enum.any?(analysis.warnings, &(&1.code == :unequal_maximum_opportunity))
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
