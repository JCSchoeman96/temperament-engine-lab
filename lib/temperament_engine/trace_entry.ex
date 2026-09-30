defmodule TemperamentEngine.TraceEntry do
  @moduledoc "One answer's normalized raw and weighted scoring vector."

  defstruct question_id: nil,
            response_id: nil,
            channel: nil,
            question_weight: nil,
            raw_contributions: %{},
            weighted_contributions: %{}
end
