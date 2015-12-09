defmodule Poker.Hand.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, nil, opts)
  end

  def init(_) do
    children = [
      worker(Poker.Hand, [], restart: :transient)
    ]

    supervise children, strategy: :simple_one_for_one
  end

  def start_hand(supervisor, table, config \\ []) do
    hand = UUID.uuid4
    Supervisor.start_child(supervisor, [hand, table, config])
    {:ok, hand}
  end
end
