defmodule TemperamentEngine.Presentation do
  @moduledoc "Resolved question and response order for one assessment presentation."

  defstruct methodology_id: nil,
            methodology_version: nil,
            question_order: [],
            response_order: %{}
end
