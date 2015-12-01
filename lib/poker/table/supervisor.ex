defmodule Poker.Table.Supervisor do
  use Supervisor

  def start_link(table_name, num_players) do
    Supervisor.start_link(__MODULE__, [table_name, num_players])
  end

  def init([table_name, num_players]) do
    players = :ets.new(:players, [:public])

    children = [
      worker(Poker.Table, [self, players, table_name, num_players])
    ]

    supervise children, strategy: :one_for_one
  end

  def start_hand(supervisor, table, players, config \\ []) do
    Supervisor.start_child(supervisor, supervisor(Poker.Hand.Supervisor, [table, players, config], restart: :transient, id: :hand_sup))
  end

  def stop_hand(supervisor) do
    Supervisor.terminate_child(supervisor, :hand_sup)
    Supervisor.delete_child(supervisor, :hand_sup)
  end
end
