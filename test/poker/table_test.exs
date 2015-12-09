defmodule Poker.TableTest do
  use ExUnit.Case, async: false
  alias Poker.Table

  @num_seats 3

  setup do
    Poker.Bank.start_link
    players = :ets.new(:players, [:public])

    {:ok, pid} = Table.start_link(:test_table, nil, players, @num_seats)
    {:ok, [manager: pid]}
  end

  test "sitting and leaving", %{manager: manager} do
    assert Table.get_state(manager) == %{hand: nil, players: [], num_seats: @num_seats}

    Table.sit(manager, :player_one, 1)
    assert [%{seat: 1, id: :player_one}] = Table.get_state(manager).players

    assert Table.sit(manager, :player_two, 1) == {:error, %{reason: :seat_taken}}
    assert Table.sit(manager, :player_two, @num_seats + 1) == {:error, %{reason: :seat_unavailable}}
    assert Table.sit(manager, :player_two, 3) == :ok

    assert [%{seat: 1, id: :player_one}, %{seat: 3, id: :player_two}] = Table.get_state(manager).players

    Table.leave(manager, :player_two)

    assert [%{seat: 1, id: :player_one}] = Table.get_state(manager).players
  end

  test "buying in and cashing out", %{manager: manager} do
    Poker.Bank.deposit(:player, 600)
    assert Table.sit(manager, :player, 1) == :ok

    assert Table.buy_in(manager, :player, 200) == :ok
    assert [%{balance: 200, seat: 1}] = Table.get_state(manager).players
    assert Poker.Bank.balance(:player) == 400

    assert Table.buy_in(manager, :player, 350) == :ok
    assert [%{balance: 550, seat: 1}] = Table.get_state(manager).players
    assert Poker.Bank.balance(:player) == 50

    assert Table.buy_in(manager, :player, 200) == {:error, %{reason: :insufficient_funds}}
    assert [%{balance: 550, seat: 1}] = Table.get_state(manager).players
    assert Poker.Bank.balance(:player) == 50

    assert Table.cash_out(manager, :player) == :ok
    assert [%{balance: 0, seat: 1}] = Table.get_state(manager).players
    assert Poker.Bank.balance(:player) == 600
  end
end
