defmodule TemperamentEngineLab.MixProject do
  use Mix.Project

  def project do
    [
      app: :temperament_engine,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      test_ignore_filters: [~r"test/support/"],
      deps: deps(),
      description: "A standalone research laboratory for deterministic temperament scoring"
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 1.4", only: :test}
    ]
  end
end
