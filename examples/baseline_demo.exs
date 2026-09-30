alias TemperamentEngine.Methodology
alias TemperamentEngine.Question
alias TemperamentEngine.Response

dimensions = ["yellow", "red", "green", "blue"]
options = [{"a", "yellow"}, {"b", "red"}, {"c", "green"}, {"d", "blue"}]

questions =
  for index <- 1..25 do
    question_id = "fc_#{String.pad_leading(Integer.to_string(index), 3, "0")}"

    responses =
      Enum.map(options, fn {suffix, dimension} ->
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

methodology = %Methodology{
  id: "synthetic_baseline_demo",
  version: "1.0.0-research",
  dimensions: dimensions,
  questions: questions,
  ranking_source: {:channel, :forced_choice}
}

answers =
  questions
  |> Enum.with_index()
  |> Map.new(fn {question, index} ->
    response = Enum.at(question.responses, rem(index * 3, length(question.responses)))
    {question.id, response.id}
  end)

{:ok, presentation} = TemperamentEngine.generate_presentation(methodology)
:ok = TemperamentEngine.validate_presentation(methodology, presentation)
{:ok, result} = TemperamentEngine.score(methodology, answers)

IO.puts("Synthetic 25-question baseline presentation")
IO.puts("Question order sample: #{inspect(Enum.take(presentation.question_order, 5))}")
IO.puts("Channel scores:")
IO.inspect(result.channel_scores)
IO.puts("Ranking:")
IO.inspect(result.ranking)
IO.puts("First three trace entries:")
IO.inspect(Enum.take(result.trace, 3), pretty: true)
