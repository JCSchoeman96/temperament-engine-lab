defmodule TemperamentEngine.ValidationError do
  @moduledoc "A machine-readable validation failure."

  defstruct code: nil, path: [], detail: nil

  @type t :: %__MODULE__{code: atom(), path: list(), detail: term()}
end
