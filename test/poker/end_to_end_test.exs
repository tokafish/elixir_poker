defmodule Poker.EndToEndTest do
  use ExUnit.Case, async: false

  import Mocks.Player, only: [as_player: 2]

  defp cards do
    "As Jd " <> # player three's cards
    "Jc Tc " <> # player one's cards
    "Js Ts " <> # player two's cards
    "Ad 9h 8s Jh Qd" |> # the board
    String.split |>
    Enum.map(&Poker.Deck.Card.from_string/1)
  end

  setup do
    Mocks.StackedDeck.stack(cards)
    Poker.Bank.start_link

    players = Enum.map ~w(player_one player_two player_three), fn (name) ->
      {:ok, player} = Mocks.Player.start_link(String.to_atom(name))
      Poker.Bank.deposit(player, 1000)
      player
    end

    {:ok, [table: :table_one, players: players, hand: :table_one_hand]}
  end

  test "betting, raising, and folding", %{table: table, players: players, hand: hand} do
    [player_one, player_two, player_thr] = players

    as_player player_one, do: Poker.Table.sit(table, 1)
    as_player player_two, do: Poker.Table.sit(table, 2)
    as_player player_thr, do: Poker.Table.sit(table, 3)

    as_player player_one, do: Poker.Table.buy_in(table, 1000)
    as_player player_two, do: Poker.Table.buy_in(table, 1000)
    as_player player_thr, do: Poker.Table.buy_in(table, 800)

    Process.whereis(table) |> Process.exit(:kill)

    :timer.sleep(100)

    {:ok, _} = Poker.Table.deal(table)

    # :timer.sleep(500)

    # Process.whereis(hand) |> Process.exit(:kill)
    # :timer.sleep(500)

    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 10)
    as_player player_one, do: :ok = Poker.Hand.bet(hand, 5)
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
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_one, do: :ok = Poker.Hand.fold(hand)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 50)

    # River
    as_player player_two, do: :ok = Poker.Hand.check(hand)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 100)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)

    :timer.sleep(100)

    as_player player_one, do: Poker.Table.cash_out(table)
    as_player player_two, do: Poker.Table.cash_out(table)
    as_player player_thr, do: Poker.Table.cash_out(table)

    assert Poker.Bank.balance(player_one) == 940
    assert Poker.Bank.balance(player_two) == 1270
    assert Poker.Bank.balance(player_thr) == 790
  end
end
