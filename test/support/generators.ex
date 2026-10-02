defmodule TemperamentEngine.Generators do
  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response

  import StreamData

  def methodologies do
    bind(tuple({integer(1..10_000), integer(1..5)}), fn {id_seed, dimension_count} ->
      dimensions =
        for index <- 1..dimension_count, do: "dimension_#{id_seed}_#{index}"

      bind(integer(1..40), fn question_count ->
        bind(list_of(question_data(dimensions), length: question_count), fn question_data ->
          questions =
            question_data
            |> Enum.with_index(1)
            |> Enum.map(fn {{type, weight, contribution_maps}, question_index} ->
              question_id = "question_#{id_seed}_#{question_index}"

              responses =
                contribution_maps
                |> Enum.with_index(1)
                |> Enum.map(fn {contributions, response_index} ->
                  %Response{
                    id: "#{question_id}_response_#{response_index}",
                    contributions: contributions
                  }
                end)

              %Question{
                id: question_id,
                type: type,
                weight: weight,
                responses: responses
              }
            end)

          ranking_source_gen =
            if Enum.any?(questions, &(&1.type == :forced_choice)) do
              map(boolean(), fn
                true -> {:channel, :forced_choice}
                false -> :none
              end)
            else
              constant(:none)
            end

          map(ranking_source_gen, fn ranking_source ->
            %Methodology{
              id: "generated_methodology_#{id_seed}",
              version: "v#{id_seed}",
              dimensions: dimensions,
              questions: questions,
              ranking_source: ranking_source
            }
          end)
        end)
      end)
    end)
  end

  def ranked_methodologies do
    map(methodologies(), fn methodology ->
      questions =
        case Enum.find_index(methodology.questions, &(&1.type == :forced_choice)) do
          nil ->
            [first | remaining] = methodology.questions
            [%{first | type: :forced_choice} | remaining]

          _index ->
            methodology.questions
        end

      %{methodology | questions: questions, ranking_source: {:channel, :forced_choice}}
    end)
  end

  def answers_for(%Methodology{} = methodology) do
    response_choices =
      Enum.map(methodology.questions, fn question ->
        member_of(Enum.map(question.responses, & &1.id))
      end)

    map(tuple(List.to_tuple(response_choices)), fn response_ids ->
      methodology.questions
      |> Enum.zip(Tuple.to_list(response_ids))
      |> Map.new(fn {question, response_id} -> {question.id, response_id} end)
    end)
  end

  defp question_data(dimensions) do
    bind(member_of([:forced_choice, :agreement_scale]), fn type ->
      bind(integer(1..10), fn weight ->
        bind(integer(1..5), fn response_count ->
          map(list_of(contribution_map(dimensions), length: response_count), fn maps ->
            {type, weight, maps}
          end)
        end)
      end)
    end)
  end

  defp contribution_map(dimensions) do
    map(
      list_of(one_of([constant(:omitted), integer(0..5)]), length: length(dimensions)),
      fn values ->
        dimensions
        |> Enum.zip(values)
        |> Enum.reject(fn {_dimension, value} -> value == :omitted end)
        |> Map.new()
      end
    )
  end
end
