defmodule Mocks.Player do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, [self, name])
  end

  defmacro as_player(player, do: block) do
    quote do
      func = fn ->
        unquote(block)
      end
      Mocks.Player.perform(unquote(player), func)
    end
  end

  def perform(player, func) do
    GenServer.call(player, {:perform, func})
  end

  def handle_call({:perform, func}, _from, state) do
    {:reply, func.(), state}
  end

  def handle_info(msg, state = [test_process, name]) do
    send test_process, {name, msg}
    {:noreply, state}
  end
end
