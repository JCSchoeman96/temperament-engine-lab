defmodule TemperamentEngine.Scoring.Scorer do
  @moduledoc "Scores semantic response IDs in one canonical methodology reduction."

  alias TemperamentEngine.Methodology.Validator, as: MethodologyValidator
  alias TemperamentEngine.Result
  alias TemperamentEngine.Scoring.Ranking
  alias TemperamentEngine.TraceEntry
  alias TemperamentEngine.ValidationError

  def score(methodology, answers) do
    with :ok <- MethodologyValidator.validate(methodology),
         :ok <- validate_answers(methodology, answers) do
      {:ok, calculate(methodology, answers)}
    end
  end

  defp validate_answers(_methodology, answers) when not is_map(answers) do
    {:error,
     [
       error(
         :invalid_answers,
         [:answers],
         "Answers must be a map of question IDs to response IDs."
       )
     ]}
  end

  defp validate_answers(methodology, answers) do
    questions = methodology.questions
    question_ids = MapSet.new(Enum.map(questions, & &1.id))

    unknown_question_errors =
      answers
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(question_ids, &1))
      |> Enum.sort_by(&:erlang.term_to_binary/1)
      |> Enum.map(
        &error(:unknown_question, [:answers, &1], "Answer references an unknown question.")
      )

    all_response_ids =
      questions
      |> Enum.flat_map(&Enum.map(&1.responses, fn response -> response.id end))
      |> MapSet.new()

    answer_errors =
      Enum.flat_map(questions, fn question ->
        case Map.fetch(answers, question.id) do
          :error ->
            [
              error(
                :missing_answer,
                [:answers, question.id],
                "Every methodology question needs one answer."
              )
            ]

          {:ok, response_id} ->
            if Enum.any?(question.responses, &(&1.id == response_id)) do
              []
            else
              if MapSet.member?(all_response_ids, response_id) do
                [
                  error(
                    :response_belongs_to_wrong_question,
                    [:answers, question.id],
                    "Selected response belongs to a different question."
                  )
                ]
              else
                [
                  error(
                    :unknown_response,
                    [:answers, question.id],
                    "Selected response ID is not defined for this question."
                  )
                ]
              end
            end
        end
      end)

    case unknown_question_errors ++ answer_errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp calculate(methodology, answers) do
    dimensions = methodology.dimensions
    channels = methodology.questions |> Enum.map(&channel_for_type(&1.type)) |> Enum.uniq()
    zeroes = Map.new(dimensions, &{&1, 0})
    initial_scores = Map.new(channels, &{&1, zeroes})

    {channel_scores, reversed_trace} =
      Enum.reduce(methodology.questions, {initial_scores, []}, fn question, {scores, trace} ->
        channel = channel_for_type(question.type)
        response = find_response!(question, Map.fetch!(answers, question.id))

        raw_contributions =
          Map.new(dimensions, fn dimension ->
            {dimension, Map.get(response.contributions, dimension, 0)}
          end)

        weighted_contributions =
          Map.new(raw_contributions, fn {dimension, contribution} ->
            {dimension, question.weight * contribution}
          end)

        updated_channel_scores =
          weighted_contributions
          |> Enum.reduce(Map.fetch!(scores, channel), fn {dimension, contribution}, totals ->
            Map.update!(totals, dimension, &(&1 + contribution))
          end)

        trace_entry = %TraceEntry{
          question_id: question.id,
          response_id: response.id,
          channel: channel,
          question_weight: question.weight,
          raw_contributions: raw_contributions,
          weighted_contributions: weighted_contributions
        }

        {Map.put(scores, channel, updated_channel_scores), [trace_entry | trace]}
      end)

    {ranking_scores, ranking, top_tie?} =
      case methodology.ranking_source do
        {:channel, :forced_choice} ->
          scores = Map.fetch!(channel_scores, :forced_choice)
          groups = Ranking.rank(scores, dimensions)
          {scores, groups, Ranking.top_tie?(groups)}

        :none ->
          {nil, nil, nil}
      end

    %Result{
      methodology_id: methodology.id,
      methodology_version: methodology.version,
      channel_scores: channel_scores,
      ranking_scores: ranking_scores,
      ranking: ranking,
      top_tie?: top_tie?,
      trace: Enum.reverse(reversed_trace)
    }
  end

  defp find_response!(question, response_id) do
    Enum.find(question.responses, &(&1.id == response_id))
  end

  defp channel_for_type(:forced_choice), do: :forced_choice
  defp channel_for_type(:agreement_scale), do: :agreement_scale

  defp error(code, path, detail), do: %ValidationError{code: code, path: path, detail: detail}
end
