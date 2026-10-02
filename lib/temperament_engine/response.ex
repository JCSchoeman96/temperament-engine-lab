defmodule TemperamentEngine.Response do
  @moduledoc "A stable answer identifier and its explicit dimension contributions."

  defstruct id: nil, contributions: %{}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          contributions: %{optional(String.t()) => non_neg_integer()}
        }
end
