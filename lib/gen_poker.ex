defmodule GenPoker do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(Poker.Bank, []),
      supervisor(Poker.Table.Supervisor, [:table_one, 6])
    ]

    opts = [strategy: :one_for_one, name: GenPoker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
