defmodule TemperamentEngine.Presentation.Generator do
  @moduledoc "Builds randomized question and forced-choice response orders."

  alias TemperamentEngine.Methodology.Validator
  alias TemperamentEngine.Presentation
  alias TemperamentEngine.Question
  alias TemperamentEngine.ValidationError

  @doc false
  def generate(methodology), do: generate(methodology, &Enum.shuffle/1)

  @doc false
  def generate(methodology, shuffle_fun) when is_function(shuffle_fun, 1) do
    with :ok <- Validator.validate(methodology) do
      questions = methodology.questions

      response_order =
        Map.new(questions, fn
          %Question{type: :forced_choice} = question ->
            {question.id, question.responses |> Enum.map(& &1.id) |> shuffle_fun.()}

          %Question{type: :agreement_scale} = question ->
            {question.id, Enum.map(question.responses, & &1.id)}
        end)

      {:ok,
       %Presentation{
         methodology_id: methodology.id,
         methodology_version: methodology.version,
         question_order: questions |> Enum.map(& &1.id) |> shuffle_fun.(),
         response_order: response_order
       }}
    end
  end

  def generate(_methodology, _shuffle_fun) do
    {:error,
     [
       %ValidationError{
         code: :invalid_shuffle_function,
         path: [:shuffle_function],
         detail: "The internal shuffle function must accept one list argument."
       }
     ]}
  end
end
