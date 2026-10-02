defmodule TemperamentEngine.ValidationError do
  @moduledoc """
  A machine-readable validation failure.

  Consumers should use `code` and `path` as the stable machine interface. `detail` is diagnostic
  copy and may change without changing the error's meaning.
  """

  defstruct code: nil, path: [], detail: nil

  @type t :: %__MODULE__{
          code: atom() | nil,
          path: [term()],
          detail: String.t() | nil
        }
end
