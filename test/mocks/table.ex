defmodule Mocks.Table do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, self, opts)
  end

  def handle_call({:update_balance, _player, -500}, _from, state) do
    {:reply, {:error, %{reason: :insufficient_funds}}, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, %{hand: nil, players: []}, state}
  end

  def handle_call(_msg, _from, state) do
    {:reply, :ok, state}
  end

  def handle_cast({:notify_player, player, msg}, test_process) do
    send test_process, {player, msg}
    {:noreply, test_process}
  end

  def handle_cast(:hand_finished, state) do
    {:noreply, state}
  end
end
