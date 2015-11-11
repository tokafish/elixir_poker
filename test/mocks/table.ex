defmodule Mocks.Table do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_call({:update_balance, _player, -500}, _from, state) do
    {:reply, {:error, :insufficient_funds}, state}
  end

  def handle_call({:update_balance, _player, _delta}, _from, state) do
    {:reply, :ok, state}
  end
end
