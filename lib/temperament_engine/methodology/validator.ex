defmodule TemperamentEngine.Methodology.Validator do
  @moduledoc "Validates methodology data before analysis, presentation or scoring."

  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response
  alias TemperamentEngine.ValidationError

  @question_types [:forced_choice, :agreement_scale]
  @machine_identifier_regex ~r/\A[A-Za-z0-9][A-Za-z0-9._-]*\z/

  @spec validate(term()) :: :ok | {:error, [ValidationError.t()]}
  def validate(%Methodology{} = methodology) do
    {dimension_errors, dimensions} = validate_dimensions(methodology.dimensions)

    errors =
      validate_identifier(methodology.id, [:id]) ++
        validate_identifier(methodology.version, [:version]) ++
        dimension_errors ++
        validate_questions(methodology.questions, dimensions) ++
        validate_ranking_source(methodology.ranking_source, methodology.questions)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  def validate(_methodology) do
    {:error, [error(:invalid_methodology, [], "Expected a Methodology struct.")]}
  end

  defp validate_identifier(value, path) do
    if valid_identifier?(value) do
      []
    else
      [
        error(
          :invalid_identifier,
          path,
          "Expected an ASCII machine identifier matching [A-Za-z0-9][A-Za-z0-9._-]*."
        )
      ]
    end
  end

  defp validate_dimensions(dimensions) when is_list(dimensions) do
    errors =
      if dimensions == [] do
        [error(:missing_dimensions, [:dimensions], "At least one dimension is required.")]
      else
        []
      end

    {identifier_errors, valid_dimensions} =
      dimensions
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {dimension, index}, {current_errors, valid} ->
        if valid_identifier?(dimension) do
          {current_errors, [dimension | valid]}
        else
          {current_errors ++
             [
               error(
                 :invalid_identifier,
                 [:dimensions, index],
                 "Expected an ASCII machine identifier matching [A-Za-z0-9][A-Za-z0-9._-]*."
               )
             ], valid}
        end
      end)

    duplicate_errors =
      duplicate_identifier_errors(
        Enum.reverse(valid_dimensions),
        [:dimensions],
        :duplicate_dimension
      )

    {errors ++ identifier_errors ++ duplicate_errors, MapSet.new(valid_dimensions)}
  end

  defp validate_dimensions(_dimensions) do
    {[
       error(
         :invalid_dimensions,
         [:dimensions],
         "Expected an ordered list of dimension identifiers."
       )
     ], MapSet.new()}
  end

  defp validate_questions(questions, dimensions) when is_list(questions) do
    empty_errors =
      if questions == [] do
        [error(:missing_questions, [:questions], "At least one question is required.")]
      else
        []
      end

    {question_errors, identifiers} =
      questions
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {question, index}, {current_errors, current_ids} ->
        case question do
          %Question{} ->
            errors = validate_question(question, index, dimensions)

            ids =
              if valid_identifier?(question.id),
                do: [question.id | current_ids],
                else: current_ids

            {current_errors ++ errors, ids}

          _ ->
            {current_errors ++
               [error(:invalid_question, [:questions, index], "Expected a Question struct.")],
             current_ids}
        end
      end)

    empty_errors ++
      question_errors ++
      duplicate_identifier_errors(Enum.reverse(identifiers), [:questions], :duplicate_question)
  end

  defp validate_questions(_questions, _dimensions) do
    [error(:invalid_questions, [:questions], "Expected an ordered list of questions.")]
  end

  defp validate_question(%Question{} = question, index, dimensions) do
    path = [:questions, index]

    validate_identifier(question.id, path ++ [:id]) ++
      validate_question_type(question.type, path ++ [:type]) ++
      validate_weight(question.weight, path ++ [:weight]) ++
      validate_metadata(question.metadata, path ++ [:metadata]) ++
      validate_responses(question.responses, dimensions, path ++ [:responses])
  end

  defp validate_question_type(type, _path) when type in @question_types, do: []

  defp validate_question_type(_type, path) do
    [
      error(
        :unsupported_question_type,
        path,
        "Supported question types are forced_choice and agreement_scale."
      )
    ]
  end

  defp validate_weight(weight, _path) when is_integer(weight) and weight >= 1, do: []

  defp validate_weight(_weight, path) do
    [
      error(
        :invalid_question_weight,
        path,
        "Question weight must be an integer greater than or equal to 1."
      )
    ]
  end

  defp validate_metadata(metadata, _path) when is_map(metadata), do: []

  defp validate_metadata(_metadata, path) do
    [error(:invalid_metadata, path, "Question metadata must be a map.")]
  end

  defp validate_responses(responses, dimensions, path) when is_list(responses) do
    empty_errors =
      if responses == [] do
        [error(:missing_responses, path, "At least one response is required for every question.")]
      else
        []
      end

    {response_errors, identifiers} =
      responses
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {response, index}, {current_errors, current_ids} ->
        case response do
          %Response{} ->
            response_path = path ++ [index]
            errors = validate_response(response, dimensions, response_path)

            ids =
              if valid_identifier?(response.id),
                do: [response.id | current_ids],
                else: current_ids

            {current_errors ++ errors, ids}

          _ ->
            {current_errors ++
               [error(:invalid_response, path ++ [index], "Expected a Response struct.")],
             current_ids}
        end
      end)

    empty_errors ++
      response_errors ++
      duplicate_identifier_errors(Enum.reverse(identifiers), path, :duplicate_response)
  end

  defp validate_responses(_responses, _dimensions, path) do
    [error(:invalid_responses, path, "Expected an ordered list of responses.")]
  end

  defp validate_response(%Response{} = response, dimensions, path) do
    validate_identifier(response.id, path ++ [:id]) ++
      validate_contributions(response.contributions, dimensions, path ++ [:contributions])
  end

  defp validate_contributions(contributions, _dimensions, path) when not is_map(contributions) do
    [error(:invalid_contributions, path, "Response contributions must be a map.")]
  end

  defp validate_contributions(contributions, dimensions, path) do
    contributions
    |> Enum.sort_by(fn {dimension, _value} -> :erlang.term_to_binary(dimension) end)
    |> Enum.flat_map(fn {dimension, value} ->
      dimension_errors =
        if MapSet.member?(dimensions, dimension) do
          []
        else
          [
            error(
              :undeclared_dimension,
              path ++ [dimension],
              "Contribution keys must reference a declared dimension."
            )
          ]
        end

      value_errors =
        if is_integer(value) and value >= 0 do
          []
        else
          [
            error(
              :invalid_contribution,
              path ++ [dimension],
              "Contribution values must be integers greater than or equal to 0."
            )
          ]
        end

      dimension_errors ++ value_errors
    end)
  end

  defp validate_ranking_source(:none, _questions), do: []

  defp validate_ranking_source({:channel, :forced_choice}, questions) when is_list(questions) do
    if Enum.any?(questions, &match?(%Question{type: :forced_choice}, &1)) do
      []
    else
      [
        error(
          :ranking_channel_unavailable,
          [:ranking_source],
          "The forced_choice ranking channel requires at least one forced-choice question."
        )
      ]
    end
  end

  defp validate_ranking_source(_ranking_source, _questions) do
    [
      error(
        :unsupported_ranking_source,
        [:ranking_source],
        "Ranking source must be :none or {:channel, :forced_choice}."
      )
    ]
  end

  defp duplicate_identifier_errors(identifiers, path, code) do
    identifiers
    |> Enum.frequencies()
    |> Enum.filter(fn {_identifier, count} -> count > 1 end)
    |> Enum.sort_by(fn {identifier, _count} -> identifier end)
    |> Enum.map(fn {identifier, _count} ->
      error(code, path, "Identifier #{inspect(identifier)} is declared more than once.")
    end)
  end

  defp valid_identifier?(value) when is_binary(value) do
    String.valid?(value) and Regex.match?(@machine_identifier_regex, value)
  end

  defp valid_identifier?(_value), do: false

  defp error(code, path, detail), do: %ValidationError{code: code, path: path, detail: detail}
end
