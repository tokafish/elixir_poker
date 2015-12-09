defmodule Poker.BankTest do
  use ExUnit.Case, async: false

  test "deposits and withdrawals" do
    Poker.Bank.start_link

    Poker.Bank.deposit(:player_one, 100)

    assert Poker.Bank.withdraw(:player_one, 75) == :ok
    assert Poker.Bank.balance(:player_one) == 25
    assert Poker.Bank.withdraw(:player_one, 75) == {:error, %{reason: :insufficient_funds}}
    assert Poker.Bank.withdraw(:player_one, -75) == :error

    assert Poker.Bank.withdraw(:player_two, 35) == {:error, %{reason: :insufficient_funds}}
    assert Poker.Bank.balance(:player_two) == 0

    Poker.Bank.deposit(:player_one, -100)
    assert Poker.Bank.balance(:player_one) == 25
    assert Poker.Bank.withdraw(:player_one, 25) == :ok
    assert Poker.Bank.balance(:player_one) == 0
  end
end
