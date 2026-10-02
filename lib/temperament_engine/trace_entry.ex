defmodule TemperamentEngine.TraceEntry do
  @moduledoc "One answer's normalized raw and weighted scoring vector."

  defstruct question_id: nil,
            response_id: nil,
            channel: nil,
            question_weight: nil,
            raw_contributions: %{},
            weighted_contributions: %{}

  @type channel :: :forced_choice | :agreement_scale
  @type dimension_values :: %{optional(String.t()) => non_neg_integer()}
  @type t :: %__MODULE__{
          question_id: String.t() | nil,
          response_id: String.t() | nil,
          channel: channel() | nil,
          question_weight: pos_integer() | nil,
          raw_contributions: dimension_values(),
          weighted_contributions: dimension_values()
        }
end
