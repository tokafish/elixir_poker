defmodule GenPoker.TableChannel do
  use GenPoker.Web, :channel

  alias Poker.Table

  def join("tables:" <> table, _payload, socket) do
    send self, :after_join
    {:ok, assign(socket, :table, table)}
  end

  def handle_in(command, payload, socket) when command in ~w(sit leave buy_in cash_out deal) do
    table = Table.whereis(socket.assigns.table)
    arguments = [table, socket.assigns.player_id] ++ payload
    result = apply(Table, String.to_atom(command), arguments)
    if result == :ok do
      broadcast! socket, "update", Table.get_state(table)
    end
    {:reply, result, socket}
  end

  def handle_info(:after_join, socket) do
    state = socket.assigns.table |> Table.whereis |> Table.get_state
    push socket, "update", state
    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end
