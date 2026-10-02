defmodule TemperamentEngine.Presentation do
  @moduledoc "Resolved question and response order for one assessment presentation."

  defstruct methodology_id: nil,
            methodology_version: nil,
            question_order: [],
            response_order: %{}

  @type t :: %__MODULE__{
          methodology_id: String.t() | nil,
          methodology_version: String.t() | nil,
          question_order: [String.t()],
          response_order: %{optional(String.t()) => [String.t()]}
        }
end
