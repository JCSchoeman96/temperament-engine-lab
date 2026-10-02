defmodule TemperamentEngine do
  @moduledoc """
  Public API for validating, analyzing, presenting and scoring synthetic research methodologies.

  Validation returns `:ok` or `{:error, errors}`. Operations that produce a value return
  `{:ok, value}` or `{:error, errors}`. Errors are `TemperamentEngine.ValidationError` structs.
  Consumers should branch on an error's `code` and `path`; `detail` is diagnostic copy.
  """

  alias TemperamentEngine.Methodology.Analyzer
  alias TemperamentEngine.Methodology.Analysis
  alias TemperamentEngine.Methodology.Validator
  alias TemperamentEngine.Presentation
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator, as: PresentationValidator
  alias TemperamentEngine.Result
  alias TemperamentEngine.Scoring.Scorer
  alias TemperamentEngine.ValidationError

  @doc "Validates methodology identifiers, dimensions, questions, responses and ranking source."
  @spec validate_methodology(term()) :: :ok | {:error, [ValidationError.t()]}
  def validate_methodology(methodology), do: Validator.validate(methodology)

  @doc "Calculates theoretical score opportunity without participant answers."
  @spec analyze_methodology(term()) :: {:ok, Analysis.t()} | {:error, [ValidationError.t()]}
  def analyze_methodology(methodology), do: Analyzer.analyze(methodology)

  @doc "Generates a randomized question and response presentation."
  @spec generate_presentation(term()) ::
          {:ok, Presentation.t()} | {:error, [ValidationError.t()]}
  def generate_presentation(methodology), do: Generator.generate(methodology)

  @doc "Checks that a presentation is an exact permutation for its methodology version."
  @spec validate_presentation(term(), term()) :: :ok | {:error, [ValidationError.t()]}
  def validate_presentation(methodology, presentation) do
    PresentationValidator.validate(methodology, presentation)
  end

  @doc "Scores complete semantic response IDs and returns channel totals, ranking and trace."
  @spec score(term(), term()) :: {:ok, Result.t()} | {:error, [ValidationError.t()]}
  def score(methodology, answers), do: Scorer.score(methodology, answers)
end
