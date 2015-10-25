defmodule Poker.RankingTest do
  use ExUnit.Case, async: true

  def cards_from_string(hand) do
    hand |> String.split(" ") |> Enum.map(&Poker.Deck.Card.from_string/1)
  end

  def assert_rank(hand, rank) do
    cards = cards_from_string(hand)
    actual_rank = Poker.Ranking.evaluate(cards) |> Poker.Ranking.description
    assert actual_rank == rank, "Expected #{hand} to have rank #{rank}, got #{actual_rank}"
  end

  test "#rank" do
    assert_rank "As Ks Qs Js Ts", :royal_flush
    assert_rank "Ks Qs Js 9s Ts", :straight_flush
    assert_rank "As 3s 2s 4s 5s", :straight_flush
    assert_rank "Ks Kd Kc Kh As", :four_of_a_kind
    assert_rank "Ks Kd Kc Kh 9s", :four_of_a_kind
    assert_rank "Ks Kd Kc 9h 9s", :full_house
    assert_rank "3h 3c 3s Jd Jc", :full_house
    assert_rank "2h 7h 8h 9h Th", :flush
    assert_rank "Ks Qc Js Ah Ts", :straight
    assert_rank "As 3d 2s 4s 5c", :straight
    assert_rank "Ks Kd Kc 9h As", :three_of_a_kind
    assert_rank "3h 3c 3s Jd Qc", :three_of_a_kind
    assert_rank "Ks Kd 9c 9h As", :two_pair
    assert_rank "3h 3c Js Jd Tc", :two_pair
    assert_rank "3h 3c 4d 4s 2c", :two_pair
    assert_rank "Ks Kd 8c 9h Js", :one_pair
    assert_rank "7h Tc 8s Jd Tc", :one_pair
    assert_rank "3h 3c 4d 5s 2c", :one_pair
    assert_rank "Ks Qd 9c 9h As", :one_pair
    assert_rank "Ks Qd 9c Jh As", :high_card
  end

  def assert_beats(hand_one, hand_two) do
    cards_one = cards_from_string(hand_one)
    cards_two = cards_from_string(hand_two)

    assert Poker.Ranking.evaluate(cards_one) > Poker.Ranking.evaluate(cards_two), "Expected #{hand_one} to be better than #{hand_two}"
  end

  def assert_ties(hand_one, hand_two) do
    cards_one = cards_from_string(hand_one)
    cards_two = cards_from_string(hand_two)

    assert Poker.Ranking.evaluate(cards_one) == Poker.Ranking.evaluate(cards_two), "Expected #{hand_one} to tie #{hand_two}"
  end

  test "winning hands" do
    assert_beats "As Ks Qs Js Ts", "Ks Qs Js Ts 9s"
    assert_ties "As Ks Qs Js Ts", "Ah Kh Qh Jh Th"

    assert_beats "Ks Kd Kc Kh As", "Ks Kd Kc Kh 9s"
    assert_beats "Ks Kd Kc Kh 9s", "Ks Kd Kc 9h 9s"
    assert_beats "Ks Kd Kc 9h 9s", "3h 3c 3s Jd Jc"
    assert_beats "3h 3c 3s Jd Jc", "2h 7h 8h 9h Th"
    assert_beats "2h 7h 8h 9h Th", "Ks Qc Js Ah Ts"
    assert_beats "Ks Qc Js Ah Ts", "As 3d 2s 4s 5c"
    assert_beats "As 3d 2s 4s 5c", "Ks Kd Kc 9h As"
    assert_beats "Ks Kd Kc 9h As", "3h 3c 3s Jd Qc"
    assert_beats "3h 3c 3s Jd Qc", "Ks Kd 9c 9h As"
    assert_beats "Ks Kd 9c 9h As", "3h 3c Js Jd Tc"
    assert_beats "3h 3c Js Jd Tc", "3h 3c 4d 4s 2c"
    assert_beats "3h 3c 4d 4s 2c", "Ks Kd 8c 9h Js"
    assert_beats "Ks Kd 8c 9h Js", "3h Tc 4s Jd Tc"
    assert_beats "3h Tc 4s Jd Tc", "3h 3c 4d 5s 2c"
    assert_beats "3h 3c 4d 5s 2c", "Ks Qd 9c 7h As"
    assert_beats "Ks Qd 9c 9h As", "Ks Qd 9c Jh As"
    assert_beats "Ks Qd 7c 9h As", "Ks Qd 9c 5h As"
  end

  def assert_best_hand(board_string, hand_string, expected_rank) do
    board = cards_from_string board_string
    hand = cards_from_string hand_string

    { ranking, _best_hand } = Poker.Ranking.best_possible_hand(board, hand)

    assert expected_rank == Poker.Ranking.description(ranking)
  end

  test "best hand" do
    assert_best_hand "Kd Ks As Js Kh", "Kc Ac", :four_of_a_kind
    assert_best_hand "Kd Ks Kc Ts 9s", "Qs Js", :straight_flush
  end
end
