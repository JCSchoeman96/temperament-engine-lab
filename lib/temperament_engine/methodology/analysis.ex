defmodule TemperamentEngine.Methodology.Analysis do
  @moduledoc "Theoretical score ranges implied by a methodology's response definitions."

  defstruct minimum_by_dimension: %{},
            maximum_by_dimension: %{},
            by_channel: %{},
            warnings: []

  @type t :: %__MODULE__{
          minimum_by_dimension: map(),
          maximum_by_dimension: map(),
          by_channel: map(),
          warnings: list()
        }
end
