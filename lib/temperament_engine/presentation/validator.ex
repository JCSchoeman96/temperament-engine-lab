defmodule TemperamentEngine.Presentation.Validator do
  @moduledoc "Validates resolved presentation permutations against their methodology."

  alias TemperamentEngine.Methodology.Validator, as: MethodologyValidator
  alias TemperamentEngine.Presentation
  alias TemperamentEngine.Question
  alias TemperamentEngine.ValidationError

  def validate(methodology, presentation) do
    with :ok <- MethodologyValidator.validate(methodology) do
      validate_presentation(methodology, presentation)
    end
  end

  defp validate_presentation(methodology, %Presentation{} = presentation) do
    errors =
      identity_errors(methodology, presentation) ++
        question_order_errors(methodology, presentation.question_order) ++
        response_order_errors(methodology, presentation.response_order)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp validate_presentation(_methodology, _presentation) do
    {:error, [error(:invalid_presentation, [], "Expected a Presentation struct.")]}
  end

  defp identity_errors(methodology, presentation) do
    id_errors =
      if methodology.id == presentation.methodology_id do
        []
      else
        [
          error(
            :methodology_identity_mismatch,
            [:methodology_id],
            "Presentation methodology ID does not match."
          )
        ]
      end

    version_errors =
      if methodology.version == presentation.methodology_version do
        []
      else
        [
          error(
            :methodology_version_mismatch,
            [:methodology_version],
            "Presentation methodology version does not match."
          )
        ]
      end

    id_errors ++ version_errors
  end

  defp question_order_errors(_methodology, question_order) when not is_list(question_order) do
    [
      error(
        :invalid_question_order,
        [:question_order],
        "Question order must be a list of question IDs."
      )
    ]
  end

  defp question_order_errors(methodology, question_order) do
    expected = Enum.map(methodology.questions, & &1.id)
    expected_set = MapSet.new(expected)

    unknown_errors =
      question_order
      |> Enum.reject(&MapSet.member?(expected_set, &1))
      |> unique_sorted()
      |> Enum.map(
        &error(:unknown_question, [:question_order, &1], "Question ID is not in the methodology.")
      )

    duplicate_errors =
      question_order
      |> duplicate_values()
      |> Enum.map(
        &error(:duplicate_question, [:question_order, &1], "Question appears more than once.")
      )

    selected_set = MapSet.new(question_order)

    missing_errors =
      expected
      |> Enum.reject(&MapSet.member?(selected_set, &1))
      |> Enum.map(
        &error(
          :missing_question,
          [:question_order, &1],
          "Question is missing from the presentation."
        )
      )

    unknown_errors ++ duplicate_errors ++ missing_errors
  end

  defp response_order_errors(_methodology, response_order) when not is_map(response_order) do
    [
      error(
        :invalid_response_order,
        [:response_order],
        "Response order must be a map of question IDs to lists."
      )
    ]
  end

  defp response_order_errors(methodology, response_order) do
    questions_by_id = Map.new(methodology.questions, &{&1.id, &1})

    unknown_question_errors =
      response_order
      |> Map.keys()
      |> Enum.reject(&Map.has_key?(questions_by_id, &1))
      |> unique_sorted()
      |> Enum.map(
        &error(
          :unknown_question,
          [:response_order, &1],
          "Response order references an unknown question."
        )
      )

    response_ids_by_question =
      Map.new(methodology.questions, fn question ->
        {question.id, MapSet.new(Enum.map(question.responses, & &1.id))}
      end)

    all_response_ids =
      methodology.questions
      |> Enum.flat_map(&Enum.map(&1.responses, fn response -> response.id end))
      |> MapSet.new()

    per_question_errors =
      Enum.flat_map(methodology.questions, fn question ->
        case Map.fetch(response_order, question.id) do
          :error ->
            missing_mapping_errors(question)

          {:ok, response_ids} when is_list(response_ids) ->
            validate_response_ids(
              question,
              response_ids,
              Map.fetch!(response_ids_by_question, question.id),
              all_response_ids
            )

          {:ok, _response_ids} ->
            [
              error(
                :invalid_response_order,
                [:response_order, question.id],
                "Response order for a question must be a list of response IDs."
              )
            ]
        end
      end)

    unknown_question_errors ++ per_question_errors
  end

  defp missing_mapping_errors(%Question{} = question) do
    [
      error(
        :missing_response_order,
        [:response_order, question.id],
        "Every methodology question needs a response order."
      )
      | Enum.map(question.responses, fn response ->
          error(
            :missing_response,
            [:response_order, question.id, response.id],
            "Response is missing from the presentation."
          )
        end)
    ]
  end

  defp validate_response_ids(question, response_ids, expected_ids, all_response_ids) do
    agreement_order_errors =
      if question.type == :agreement_scale and
           response_ids != Enum.map(question.responses, & &1.id) do
        [
          error(
            :agreement_response_order_changed,
            [:response_order, question.id],
            "Agreement-scale responses must retain methodology-declared order."
          )
        ]
      else
        []
      end

    unknown_errors =
      response_ids
      |> Enum.reject(&MapSet.member?(expected_ids, &1))
      |> unique_sorted()
      |> Enum.map(fn response_id ->
        if MapSet.member?(all_response_ids, response_id) do
          error(
            :response_belongs_to_wrong_question,
            [:response_order, question.id, response_id],
            "Response belongs to a different methodology question."
          )
        else
          error(
            :unknown_response,
            [:response_order, question.id, response_id],
            "Response ID is not in this question's methodology."
          )
        end
      end)

    duplicate_errors =
      response_ids
      |> duplicate_values()
      |> Enum.map(
        &error(
          :duplicate_response,
          [:response_order, question.id, &1],
          "Response appears more than once."
        )
      )

    selected_set =
      response_ids
      |> Enum.filter(&MapSet.member?(expected_ids, &1))
      |> MapSet.new()

    missing_errors =
      question.responses
      |> Enum.map(& &1.id)
      |> Enum.reject(&MapSet.member?(selected_set, &1))
      |> Enum.map(
        &error(
          :missing_response,
          [:response_order, question.id, &1],
          "Response is missing from the presentation."
        )
      )

    agreement_order_errors ++ unknown_errors ++ duplicate_errors ++ missing_errors
  end

  defp duplicate_values(values) do
    values
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort_by(&:erlang.term_to_binary/1)
  end

  defp unique_sorted(values) do
    values
    |> Enum.uniq()
    |> Enum.sort_by(&:erlang.term_to_binary/1)
  end

  defp error(code, path, detail), do: %ValidationError{code: code, path: path, detail: detail}
end
