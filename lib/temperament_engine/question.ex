defmodule TemperamentEngine.Question do
  @moduledoc "A scored item with stable semantic responses."

  defstruct id: nil,
            type: nil,
            weight: nil,
            responses: [],
            metadata: %{}
end
