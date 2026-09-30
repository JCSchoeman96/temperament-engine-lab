defmodule TemperamentEngine.Generators do
  import StreamData

  def baseline_choice_indices(count), do: list_of(integer(0..3), length: count)

  def positive_scales, do: integer(1..10)

  def contributions, do: integer(0..20)

  def positive_contributions, do: integer(1..20)
end
