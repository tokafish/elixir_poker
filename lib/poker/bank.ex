defmodule Poker.Bank do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, %{}, name: via_tuple)
  end

  def deposit(player, amount) do
    GenServer.cast(via_tuple, {:deposit, player, amount})
  end

  def withdraw(player, amount) do
    GenServer.call(via_tuple, {:withdraw, player, amount})
  end

  def balance(player) do
    GenServer.call(via_tuple, {:balance, player})
  end

  defp via_tuple, do: {:via, :gproc, {:n, :l, __MODULE__}}

  def handle_cast({:deposit, player, amount}, state) when amount >= 0 do
    {
      :noreply,
      Map.update(state, player, amount, fn current -> current + amount end)
    }
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_call({:withdraw, player, amount}, _from, state) when amount >= 0 do
    case Map.fetch(state, player) do
      {:ok, current} when current >= amount ->
        {:reply, :ok, Map.put(state, player, current - amount)}
      _ ->
        {:reply, {:error, %{reason: :insufficient_funds}}, state}
    end
  end

  def handle_call({:balance, player}, _from, state) do
    case Map.fetch(state, player) do
      {:ok, balance} -> {:reply, balance, state}
      _ -> {:reply, 0, state}
    end
  end

  def handle_call(_msg, _from, state) do
    {:reply, :error, state}
  end
end
