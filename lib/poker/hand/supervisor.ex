defmodule Poker.Hand.Supervisor do
  use Supervisor

  def start_link(table, players, config) do
    Supervisor.start_link(__MODULE__, [table, players, config])
  end

  def init([table, players, config]) do
    hand_name = String.to_atom("#{table}_hand")
    children = [
      worker(Poker.Hand, [table, players, config, [name: hand_name]], restart: :transient)
    ]

    supervise children, strategy: :one_for_one
  end
end
