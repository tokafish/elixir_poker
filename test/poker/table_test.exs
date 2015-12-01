defmodule Poker.TableTest do
  use ExUnit.Case, async: false

  @num_seats 3

  setup do
    Poker.Bank.start_link
    players = :ets.new(:players, [:public])

    {:ok, table} = Poker.Table.start_link(nil, players, :table_name, @num_seats)
    {:ok, [table: table]}
  end

  test "sitting and leaving", %{table: table} do
    assert Poker.Table.players(table) == []

    player_two = self
    spawn fn ->
      Poker.Table.sit(table, 1)
      send player_two, :proceed
    end

    assert_receive :proceed
    assert [%{seat: 1}] = Poker.Table.players(table)

    assert Poker.Table.sit(table, 1) == {:error, :seat_taken}
    assert Poker.Table.sit(table, @num_seats + 1) == {:error, :seat_unavailable}
    assert Poker.Table.sit(table, 3) == :ok

    assert [%{seat: 1}, %{seat: 3}] = Poker.Table.players(table)

    Poker.Table.leave(table)

    assert [%{seat: 1}] = Poker.Table.players(table)
  end

  test "buying in and cashing out", %{table: table} do
    Poker.Bank.deposit(self, 600)
    assert Poker.Table.sit(table, 1) == :ok

    assert Poker.Table.buy_in(table, 200) == :ok
    assert [%{balance: 200, seat: 1}] = Poker.Table.players(table)
    assert Poker.Bank.balance(self) == 400

    assert Poker.Table.buy_in(table, 350) == :ok
    assert [%{balance: 550, seat: 1}] = Poker.Table.players(table)
    assert Poker.Bank.balance(self) == 50

    assert Poker.Table.buy_in(table, 200) == {:error, :insufficient_funds}
    assert [%{balance: 550, seat: 1}] = Poker.Table.players(table)
    assert Poker.Bank.balance(self) == 50

    assert Poker.Table.cash_out(table) == :ok
    assert [%{balance: 0, seat: 1}] = Poker.Table.players(table)
    assert Poker.Bank.balance(self) == 600
  end
end
