defmodule TemperamentEngine.FacadeTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Fixtures

  test "core values have the documented fields and defaults" do
    assert Map.from_struct(struct(TemperamentEngine.Methodology)) == %{
             id: nil,
             version: nil,
             dimensions: [],
             questions: [],
             ranking_source: nil
           }

    assert Map.from_struct(struct(TemperamentEngine.Question)) == %{
             id: nil,
             type: nil,
             weight: nil,
             responses: [],
             metadata: %{}
           }

    assert Map.from_struct(struct(TemperamentEngine.Response)) == %{
             id: nil,
             contributions: %{}
           }

    assert Map.from_struct(struct(TemperamentEngine.Presentation)) == %{
             methodology_id: nil,
             methodology_version: nil,
             question_order: [],
             response_order: %{}
           }

    assert Map.from_struct(struct(TemperamentEngine.Result)) == %{
             methodology_id: nil,
             methodology_version: nil,
             channel_scores: %{},
             ranking_scores: nil,
             ranking: nil,
             top_tie?: nil,
             trace: []
           }

    assert Map.from_struct(struct(TemperamentEngine.TraceEntry)) == %{
             question_id: nil,
             response_id: nil,
             channel: nil,
             question_weight: nil,
             raw_contributions: %{},
             weighted_contributions: %{}
           }

    assert Map.from_struct(struct(TemperamentEngine.ValidationError)) == %{
             code: nil,
             path: [],
             detail: nil
           }
  end

  test "exposes validation, analysis, presentation and scoring through one facade" do
    methodology = Fixtures.mixed_methodology()

    assert :ok == TemperamentEngine.validate_methodology(methodology)
    assert {:ok, analysis} = TemperamentEngine.analyze_methodology(methodology)
    assert analysis.by_channel.forced_choice
    assert analysis.by_channel.agreement_scale

    assert {:ok, presentation} = TemperamentEngine.generate_presentation(methodology)
    assert :ok == TemperamentEngine.validate_presentation(methodology, presentation)

    assert {:ok, result} = TemperamentEngine.score(methodology, Fixtures.answers_for(methodology))
    assert result.methodology_id == methodology.id
    assert result.ranking == nil
  end

  test "facade validation fails closed for malformed methodology" do
    assert {:error, errors} = TemperamentEngine.validate_methodology(:invalid)
    assert Enum.any?(errors, &(&1.code == :invalid_methodology))
  end
end
