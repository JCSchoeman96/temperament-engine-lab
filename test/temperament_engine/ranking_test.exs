defmodule TemperamentEngine.RankingTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Scoring.Ranking

  test "groups equal integer scores and assigns competition places" do
    scores = %{"yellow" => 42, "red" => 31, "blue" => 31, "green" => 18}

    assert Ranking.rank(scores, ["yellow", "red", "green", "blue"]) == [
             %{place: 1, score: 42, dimensions: ["yellow"]},
             %{place: 2, score: 31, dimensions: ["red", "blue"]},
             %{place: 4, score: 18, dimensions: ["green"]}
           ]
  end

  test "reports an exact top tie and lower-rank tie" do
    scores = %{"yellow" => 7, "red" => 7, "green" => 2, "blue" => 2}
    groups = Ranking.rank(scores, ["yellow", "red", "green", "blue"])

    assert groups == [
             %{place: 1, score: 7, dimensions: ["yellow", "red"]},
             %{place: 3, score: 2, dimensions: ["green", "blue"]}
           ]

    assert Ranking.top_tie?(groups)
  end

  test "does not report a top tie when only lower groups are tied" do
    groups =
      Ranking.rank(%{"yellow" => 8, "red" => 4, "green" => 4, "blue" => 1}, [
        "yellow",
        "red",
        "green",
        "blue"
      ])

    assert groups == [
             %{place: 1, score: 8, dimensions: ["yellow"]},
             %{place: 2, score: 4, dimensions: ["red", "green"]},
             %{place: 4, score: 1, dimensions: ["blue"]}
           ]

    refute Ranking.top_tie?(groups)
  end

  test "uses methodology dimension order only within a tie" do
    scores = %{"yellow" => 5, "red" => 5, "green" => 5}

    assert Ranking.rank(scores, ["green", "yellow", "red"]) == [
             %{place: 1, score: 5, dimensions: ["green", "yellow", "red"]}
           ]

    assert Ranking.top_tie?(Ranking.rank(scores, ["green", "yellow", "red"]))
  end
end
