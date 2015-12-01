defmodule Poker.HandTest do
  use ExUnit.Case, async: false

  import Mocks.Player, only: [as_player: 2]

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

    players = ~w(player_one player_two player_three) |>
      Enum.map(fn name ->
        {:ok, player} = Mocks.Player.start_link(String.to_atom(name))
        player
      end)

    {:ok, [players: players, table: table]}
  end

  test "betting, raising, and folding", %{players: players, table: table} do
    [player_one, player_two, player_thr] = players

    {:ok, hand} = Poker.Hand.start_link(table, players)

    # Pre-Flop
    assert_receive {:player_one, {:hand_state, %{active: false, board: [], pot: 15}}}
    assert_receive {:player_two, {:hand_state, %{active: false, board: [], pot: 15}}}
    assert_receive {:player_three, {:hand_state, %{active: true, board: [], pot: 15}}}

    as_player player_thr, do: {:error, :not_enough} = Poker.Hand.bet(hand, 5)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 10)
    assert_receive {:player_one, {:hand_state, %{active: true, board: [], pot: 25}}}
    assert_receive {:player_two, {:hand_state, %{active: false, board: [], pot: 25}}}
    assert_receive {:player_three, {:hand_state, %{active: false, board: [], pot: 25}}}

    as_player player_thr, do: {:error, :not_active} = Poker.Hand.bet(hand, 10)
    as_player player_one, do: :ok = Poker.Hand.bet(hand, 5)
    assert_receive {:player_one, {:hand_state, %{active: false, board: [], pot: 30}}}
    assert_receive {:player_two, {:hand_state, %{active: true, board: [], pot: 30}}}
    assert_receive {:player_three, {:hand_state, %{active: false, board: [], pot: 30}}}

    as_player player_two, do: :ok = Poker.Hand.check(hand)

    # Flop
    as_player player_one, do: :ok = Poker.Hand.check(hand)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 25)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_one, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 25)

    # Turn
    as_player player_one, do: :ok = Poker.Hand.check(hand)
    as_player player_two, do: :ok = Poker.Hand.check(hand)
    as_player player_one, do: {:error, :not_active} = Poker.Hand.fold(hand)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_one, do: :ok = Poker.Hand.fold(hand)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 50)

    # River
    as_player player_two, do: :ok = Poker.Hand.check(hand)
    as_player player_thr, do: {:error, :insufficient_funds} = Poker.Hand.bet(hand, 500)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 100)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
  end
end
