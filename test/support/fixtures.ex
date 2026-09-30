defmodule TemperamentEngine.Fixtures do
  alias TemperamentEngine.Methodology
  alias TemperamentEngine.Question
  alias TemperamentEngine.Response

  @dimensions ["yellow", "red", "green", "blue"]
  @option_dimensions [{"a", "yellow"}, {"b", "red"}, {"c", "green"}, {"d", "blue"}]
  @agreement_ids ["strongly_disagree", "disagree", "agree", "strongly_agree"]

  def dimensions, do: @dimensions

  def agreement_response_ids, do: @agreement_ids

  def baseline_methodology do
    questions =
      for index <- 1..25 do
        question_id = "fc_#{String.pad_leading(Integer.to_string(index), 3, "0")}"

        responses =
          Enum.map(@option_dimensions, fn {letter, dimension} ->
            %Response{
              id: "#{question_id}_#{letter}",
              contributions: %{dimension => 1}
            }
          end)

        %Question{
          id: question_id,
          type: :forced_choice,
          weight: 1,
          responses: responses,
          metadata: %{synthetic: true}
        }
      end

    %Methodology{
      id: "synthetic_baseline",
      version: "1.0.0-research",
      dimensions: @dimensions,
      questions: questions,
      ranking_source: {:channel, :forced_choice}
    }
  end

  def weighted_methodology do
    first_question = %Question{
      id: "weighted_001",
      type: :forced_choice,
      weight: 2,
      responses: [
        %Response{id: "weighted_001_a", contributions: %{"yellow" => 2, "red" => 1}},
        %Response{id: "weighted_001_b", contributions: %{"blue" => 1}},
        %Response{id: "weighted_001_c", contributions: %{}}
      ],
      metadata: %{synthetic: true, target_facet: "multi_signal"}
    }

    second_question = %Question{
      id: "weighted_002",
      type: :forced_choice,
      weight: 3,
      responses: [
        %Response{id: "weighted_002_a", contributions: %{"red" => 2}},
        %Response{id: "weighted_002_b", contributions: %{"green" => 1}},
        %Response{id: "weighted_002_c", contributions: %{}}
      ],
      metadata: %{synthetic: true}
    }

    %Methodology{
      id: "synthetic_weighted",
      version: "1.0.0-research",
      dimensions: @dimensions,
      questions: [first_question, second_question],
      ranking_source: {:channel, :forced_choice}
    }
  end

  def ranking_methodology do
    pairs = [
      {"tie_001", %{"yellow" => 1, "red" => 1}},
      {"tie_002", %{"yellow" => 1, "red" => 1}},
      {"tie_003", %{"green" => 1, "blue" => 1}}
    ]

    questions =
      Enum.map(pairs, fn {question_id, contributions} ->
        %Question{
          id: question_id,
          type: :forced_choice,
          weight: 1,
          responses: [
            %Response{id: "#{question_id}_selected", contributions: contributions},
            %Response{id: "#{question_id}_zero", contributions: %{}}
          ]
        }
      end)

    %Methodology{
      id: "synthetic_ties",
      version: "1.0.0-research",
      dimensions: @dimensions,
      questions: questions,
      ranking_source: {:channel, :forced_choice}
    }
  end

  def mixed_methodology do
    forced_choice = %Question{
      id: "fc_mixed_001",
      type: :forced_choice,
      weight: 1,
      responses:
        Enum.map(@option_dimensions, fn {letter, dimension} ->
          %Response{id: "fc_mixed_001_#{letter}", contributions: %{dimension => 1}}
        end),
      metadata: %{synthetic: true}
    }

    agreement = %Question{
      id: "ag_synthetic_01",
      type: :agreement_scale,
      weight: 1,
      responses:
        Enum.with_index(@agreement_ids)
        |> Enum.map(fn {response_id, value} ->
          %Response{id: "ag_synthetic_01_#{response_id}", contributions: %{"blue" => value}}
        end),
      metadata: %{synthetic: true, target_facet: "deliberation"}
    }

    %Methodology{
      id: "synthetic_mixed",
      version: "1.0.0-research",
      dimensions: @dimensions,
      questions: [forced_choice, agreement],
      ranking_source: :none
    }
  end

  def answers_for(methodology, response_index \\ 0) do
    Map.new(methodology.questions, fn question ->
      response = Enum.at(question.responses, rem(response_index, length(question.responses)))
      {question.id, response.id}
    end)
  end
end
