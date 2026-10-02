defmodule TemperamentEngine.Methodology.Analysis do
  @moduledoc """
  Channel-scoped theoretical score ranges implied by response definitions.

  Minimum and maximum values are marginal for each dimension. The maxima across dimensions can
  come from different responses and therefore do not necessarily describe a jointly reachable
  score vector.
  """

  defstruct by_channel: %{}, warnings: []

  @type channel :: :forced_choice | :agreement_scale
  @type dimension_range :: %{optional(String.t()) => non_neg_integer()}
  @type channel_range :: %{
          marginal_minimum_by_dimension: dimension_range(),
          marginal_maximum_by_dimension: dimension_range()
        }
  @type warning :: %{code: atom(), path: [term()], detail: String.t()}

  @type t :: %__MODULE__{
          by_channel: %{optional(channel()) => channel_range()},
          warnings: [warning()]
        }
end
