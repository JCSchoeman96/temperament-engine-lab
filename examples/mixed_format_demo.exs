alias TemperamentEngine.Methodology
alias TemperamentEngine.Question
alias TemperamentEngine.Response

dimensions = ["yellow", "red", "green", "blue"]
forced_choice_options = [{"a", "yellow"}, {"b", "red"}, {"c", "green"}, {"d", "blue"}]

forced_choice_question = fn question_id ->
  responses =
    Enum.map(forced_choice_options, fn {suffix, dimension} ->
      %Response{id: "#{question_id}_#{suffix}", contributions: %{dimension => 1}}
    end)

  %Question{
    id: question_id,
    type: :forced_choice,
    weight: 1,
    responses: responses,
    metadata: %{synthetic: true}
  }
end

agreement_ids = ["strongly_disagree", "disagree", "agree", "strongly_agree"]

agreement_question = %Question{
  id: "ag_synthetic_01",
  type: :agreement_scale,
  weight: 1,
  responses:
    Enum.with_index(agreement_ids)
    |> Enum.map(fn {response_id, value} ->
      %Response{id: "ag_synthetic_01_#{response_id}", contributions: %{"blue" => value}}
    end),
  metadata: %{synthetic: true, target_facet: "deliberation"}
}

questions = [
  forced_choice_question.("fc_synthetic_01"),
  agreement_question,
  forced_choice_question.("fc_synthetic_02"),
  forced_choice_question.("fc_synthetic_03")
]

methodology = %Methodology{
  id: "synthetic_mixed_demo",
  version: "1.0.0-research",
  dimensions: dimensions,
  questions: questions,
  ranking_source: :none
}

answers = %{
  "fc_synthetic_01" => "fc_synthetic_01_c",
  "ag_synthetic_01" => "ag_synthetic_01_agree",
  "fc_synthetic_02" => "fc_synthetic_02_a",
  "fc_synthetic_03" => "fc_synthetic_03_d"
}

{:ok, presentation} = TemperamentEngine.generate_presentation(methodology)
:ok = TemperamentEngine.validate_presentation(methodology, presentation)
{:ok, result} = TemperamentEngine.score(methodology, answers)

IO.puts("Synthetic mixed-format presentation")
IO.puts("Generated question order: #{inspect(presentation.question_order)}")

IO.puts("Forced-choice declared and presented response orders:")

for question <- questions, question.type == :forced_choice do
  declared = Enum.map(question.responses, & &1.id)
  presented = presentation.response_order[question.id]
  IO.puts("  #{question.id}: declared=#{inspect(declared)} presented=#{inspect(presented)}")
end

declared_agreement = Enum.map(agreement_question.responses, & &1.id)
presented_agreement = presentation.response_order[agreement_question.id]
IO.puts("Agreement declared order: #{inspect(declared_agreement)}")
IO.puts("Agreement presented order: #{inspect(presented_agreement)}")

IO.puts("Separate channel scores:")
IO.inspect(result.channel_scores)
IO.puts("Ranking source is disabled; ranking_scores=#{inspect(result.ranking_scores)}")
IO.puts("Ranking=#{inspect(result.ranking)}; no combined ranking was produced.")
