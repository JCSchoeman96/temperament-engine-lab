defmodule TemperamentEngine.RankingTest do
  use ExUnit.Case, async: true

  alias TemperamentEngine.Scoring.Ranking

  test "groups equal integer scores without using declaration order to break ties" do
    scores = %{"yellow" => 42, "red" => 31, "blue" => 31, "green" => 18}

    assert Ranking.rank(scores, ["yellow", "red", "green", "blue"]) == [
             ["yellow"],
             ["red", "blue"],
             ["green"]
           ]
  end

  test "reports an exact top tie and lower-rank tie" do
    scores = %{"yellow" => 7, "red" => 7, "green" => 2, "blue" => 2}
    groups = Ranking.rank(scores, ["yellow", "red", "green", "blue"])

    assert groups == [["yellow", "red"], ["green", "blue"]]
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

    assert groups == [["yellow"], ["red", "green"], ["blue"]]
    refute Ranking.top_tie?(groups)
  end

  test "uses methodology dimension order only to present members within a tie" do
    scores = %{"yellow" => 5, "red" => 5, "green" => 5}

    assert Ranking.rank(scores, ["green", "yellow", "red"]) == [["green", "yellow", "red"]]
    assert Ranking.top_tie?([["green", "yellow", "red"]])
  end
end
