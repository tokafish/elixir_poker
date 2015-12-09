defmodule Poker.EndToEndTest do
  use ExUnit.Case, async: false

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

    players = Enum.map ~w(player_one player_two player_three), fn player ->
      Poker.Bank.deposit(player, 1000)
      player
    end

    {:ok, _} = Poker.Table.Supervisor.start_link("test_table", 6)

    {:ok, [table: Poker.Table.whereis("test_table"), players: players]}
  end

  test "betting, raising, and folding", %{table: table, players: players} do
    [player_one, player_two, player_thr] = players

    Poker.Table.sit(table, player_one, 1)
    Poker.Table.sit(table, player_two, 2)
    Poker.Table.sit(table, player_thr, 3)

    Poker.Table.buy_in(table, player_one, 1000)
    Poker.Table.buy_in(table, player_two, 1000)
    Poker.Table.buy_in(table, player_thr, 800)

    Process.exit(table, :kill)

    :timer.sleep(100)
    table = Poker.Table.whereis("test_table")

    :ok = Poker.Table.deal(table)
    hand = Poker.Table.get_state(table).hand |> Poker.Hand.whereis

    # :timer.sleep(500)

    # :global.whereis_name(elem(hand, 1)) |> Process.exit(:kill)
    # :timer.sleep(500)

    :ok = Poker.Hand.bet(hand, player_thr, 10)
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
    :ok = Poker.Hand.bet(hand, player_thr, 50)
    :ok = Poker.Hand.fold(hand, player_one)
    :ok = Poker.Hand.bet(hand, player_two, 50)

    # River
    :ok = Poker.Hand.check(hand, player_two)
    :ok = Poker.Hand.bet(hand, player_thr, 50)
    :ok = Poker.Hand.bet(hand, player_two, 100)
    :ok = Poker.Hand.bet(hand, player_thr, 50)

    Poker.Table.cash_out(table, player_one)
    Poker.Table.cash_out(table, player_two)
    Poker.Table.cash_out(table, player_thr)

    assert Poker.Bank.balance(player_one) == 940
    assert Poker.Bank.balance(player_two) == 1270
    assert Poker.Bank.balance(player_thr) == 790
  end
end
