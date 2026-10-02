defmodule TemperamentEngine.Methodology do
  @moduledoc "Versioned, ordered scoring configuration for the research engine."

  alias TemperamentEngine.Question

  defstruct id: nil,
            version: nil,
            dimensions: [],
            questions: [],
            ranking_source: nil

  @type machine_id :: String.t()
  @type ranking_source :: :none | {:channel, :forced_choice}
  @type t :: %__MODULE__{
          id: machine_id() | nil,
          version: machine_id() | nil,
          dimensions: [machine_id()],
          questions: [Question.t()],
          ranking_source: ranking_source() | nil
        }
end
