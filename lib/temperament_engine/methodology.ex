defmodule TemperamentEngine.Methodology do
  @moduledoc "Versioned, ordered scoring configuration for the research engine."

  defstruct id: nil,
            version: nil,
            dimensions: [],
            questions: [],
            ranking_source: nil
end
