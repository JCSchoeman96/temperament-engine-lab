defmodule TemperamentEngine.Question do
  @moduledoc "A scored item with stable semantic responses."

  alias TemperamentEngine.Response

  defstruct id: nil,
            type: nil,
            weight: nil,
            responses: [],
            metadata: %{}

  @type question_type :: :forced_choice | :agreement_scale
  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: question_type() | nil,
          weight: pos_integer() | nil,
          responses: [Response.t()],
          metadata: map()
        }
end
