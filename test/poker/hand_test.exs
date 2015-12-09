defmodule Poker.HandTest do
  use ExUnit.Case, async: false

  defp cards do
    "As Jd " <> # player one's cards
    "Jc Tc " <> # player two's cards
    "Js Ts " <> # player three's cards
    "Ad 9h 8s Jh Qd" |> # the board
    String.split |>
    Enum.map(&Poker.Deck.Card.from_string/1)
  end

  setup do
    Mocks.StackedDeck.stack(cards)
    {:ok, table} = Mocks.Table.start_link
    players = [:one, :two, :three]

    {:ok, [players: players, table: table]}
  end

  test "betting, raising, and folding", %{players: players, table: table} do
    [player_one, player_two, player_thr] = players

    {:ok, hand} = Poker.Hand.start_link("test_hand", table)
    Poker.Hand.deal(hand, players)
    # Pre-Flop

    {:error, %{reason: :not_enough}} = Poker.Hand.bet(hand, player_thr, 5)
    :ok = Poker.Hand.bet(hand, player_thr, 10)

    {:error, %{reason: :not_active}} = Poker.Hand.bet(hand, player_thr, 10)
    :ok = Poker.Hand.bet(hand, player_one, 5)

    :ok = Poker.Hand.check(hand, player_two)

    # Flop
    :ok = Poker.Hand.check(hand, player_one)
    :ok = Poker.Hand.bet(hand, player_two, 25)
    :ok = Poker.Hand.bet(hand, player_thr, 50)
    :ok = Poker.Hand.bet(hand, player_one, 50)
    :ok = Poker.Hand.bet(hand, player_two, 25)

    # Turn
    :ok = Poker.Hand.check(hand, player_one)
    :ok = Poker.Hand.check(hand, player_two)
    {:error, %{reason: :not_active}} = Poker.Hand.fold(hand, player_one)
    :ok = Poker.Hand.bet(hand, player_thr, 50)
    :ok = Poker.Hand.fold(hand, player_one)
    :ok = Poker.Hand.bet(hand, player_two, 50)

    # River
    :ok = Poker.Hand.check(hand, player_two)
    {:error, %{reason: :insufficient_funds}} = Poker.Hand.bet(hand, player_thr, 500)
    :ok = Poker.Hand.bet(hand, player_thr, 50)
    :ok = Poker.Hand.bet(hand, player_two, 100)
    :ok = Poker.Hand.bet(hand, player_thr, 50)
  end
end
