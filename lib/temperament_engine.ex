defmodule TemperamentEngine do
  @moduledoc """
  Public API for validating, analyzing, presenting and scoring synthetic research methodologies.

  Validation returns `:ok` or `{:error, errors}`. Operations that produce a value return
  `{:ok, value}` or `{:error, errors}`. Errors are `TemperamentEngine.ValidationError` structs.
  """

  alias TemperamentEngine.Methodology.Analyzer
  alias TemperamentEngine.Methodology.Validator
  alias TemperamentEngine.Presentation.Generator
  alias TemperamentEngine.Presentation.Validator, as: PresentationValidator
  alias TemperamentEngine.Scoring.Scorer

  @doc "Validates methodology identifiers, dimensions, questions, responses and ranking source."
  def validate_methodology(methodology), do: Validator.validate(methodology)

  @doc "Calculates theoretical score opportunity without participant answers."
  def analyze_methodology(methodology), do: Analyzer.analyze(methodology)

  @doc "Generates a randomized question and response presentation."
  def generate_presentation(methodology), do: Generator.generate(methodology)

  @doc "Checks that a presentation is an exact permutation for its methodology version."
  def validate_presentation(methodology, presentation) do
    PresentationValidator.validate(methodology, presentation)
  end

  @doc "Scores complete semantic response IDs and returns channel totals, ranking and trace."
  def score(methodology, answers), do: Scorer.score(methodology, answers)
end
