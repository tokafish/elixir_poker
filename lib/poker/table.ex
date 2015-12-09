defmodule Poker.Table do
  use GenServer

  def start_link(table, sup, storage, num_seats) do
    GenServer.start_link(__MODULE__, [table, sup, storage, num_seats], name: via_tuple(table))
  end

  defp via_tuple(table), do: {:via, :gproc, {:n, :l, {:table, table}}}

  def whereis(table) do
    :gproc.whereis_name({:n, :l, {:table, table}})
  end

  def sit(table, player, seat) do
    GenServer.call(table, {:sit, player, seat})
  end

  def leave(table, player) do
    GenServer.call(table, {:leave, player})
  end

  def buy_in(table, player, amount) do
    GenServer.call(table, {:buy_in, player, amount})
  end

  def cash_out(table, player) do
    GenServer.call(table, {:cash_out, player})
  end

  def deal(table, _player \\ nil) do
    GenServer.call(table, :deal)
  end

  def hand_finished(table) do
    GenServer.cast(table, :hand_finished)
  end

  def update_balance(table, player, delta) do
    GenServer.call(table, {:update_balance, player, delta})
  end

  def get_state(table) do
    GenServer.call(table, :get_state)
  end

  ### GenServer callbacks
  def init([table, sup, storage, num_seats]) do
    {:ok, %{table: table, sup: sup, storage: storage, num_seats: num_seats, hand: nil}}
  end

  def handle_call({:sit, _, seat}, _from, state = %{num_seats: num_seats}) when seat < 1 or seat > num_seats do
    {:reply, {:error, %{reason: :seat_unavailable}}, state}
  end

  def handle_call({:sit, player, seat}, _, state) when is_integer(seat) do
    {:reply, seat_player(state, player, seat), state}
  end

  def handle_call({:leave, player}, _, state = %{hand: nil}) do
    case get_player(state, player) do
      {:ok, %{balance: 0}} ->
        unseat_player(state, player)
        {:reply, :ok, state}
      {:ok, %{balance: balance}} when balance > 0 ->
        {:reply, {:error, %{reason: :player_has_balance}}, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:buy_in, player, amount}, _, state = %{hand: nil}) when amount > 0 do
    case state |> get_player(player) |> withdraw_funds(amount) do
      :ok ->
        modify_balance(state, player, amount)
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:cash_out, player}, _, state = %{hand: nil}) do
    case clear_balance(state, player) do
      {:ok, balance} ->
        Poker.Bank.deposit(player, balance)
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {
      :reply,
      %{hand: state.hand, players: get_players(state), num_seats: state.num_seats},
      state}
  end

  def handle_call({:update_balance, player, delta}, _from, state) when delta >= 0 do
    case get_player(state, player) do
      {:ok, _} ->
        modify_balance(state, player, delta)
        {:reply, :ok, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:update_balance, player, delta}, _from, state) when delta < 0 do
    case get_player(state, player) do
      {:ok, %{balance: balance}} when balance + delta >= 0 ->
        modify_balance(state, player, delta)
        {:reply, :ok, state}
      {:ok, _} ->
        {:reply, {:error, %{reason: :insufficient_funds}}, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:deal, _from, state = %{hand: nil}) do
    players = state |> get_players |> Enum.map(&(&1.id))

    {:ok, hand} = Poker.Hand.Supervisor.start_hand(state.sup, via_tuple(state.table))

    hand |> Poker.Hand.whereis |> Poker.Hand.deal(players)

    {:reply, :ok, %{state | hand: hand}}
  end

  def handle_call(:deal, _from, state) do
    {:reply, {:error, %{reason: :hand_in_progress}}, state}
  end

  def handle_cast(:hand_finished, state) do
    {:noreply, %{state | hand: nil}}
  end

  defp withdraw_funds({:ok, %{id: pid}}, amount), do: Poker.Bank.withdraw(pid, amount)
  defp withdraw_funds(error, _amount), do: error

  defp seat_player(%{storage: storage}, player, seat) do
    case :ets.match_object(storage, {:_, seat, :_}) do
      [] ->
        :ets.insert(storage, {{:player, player}, seat, 0})
        :ok
      _ -> {:error, %{reason: :seat_taken}}
    end
  end

  defp unseat_player(state, player) do
    :ets.delete(state.storage, {:player, player})
  end

  defp modify_balance(state, player, delta) do
    :ets.update_counter(state.storage, {:player, player}, {3, delta})
  end

  defp clear_balance(state, player) do
    case get_player(state, player) do
      {:ok, %{balance: balance}} ->
        :ets.update_element(state.storage, {:player, player}, {3, 0})
        {:ok, balance}
      error ->
        error
    end
  end

  defp get_players(state) do
    state.storage |>
      :ets.select([{{{:player, :_}, :_, :_}, [], [:"$_"]}]) |>
      Enum.sort_by(fn {_, seat, _} -> seat end) |>
      Enum.map(&player_to_map/1)
  end

  defp get_player(state, player) do
    case :ets.lookup(state.storage, {:player, player}) do
      [] -> {:error, %{reason: :not_at_table}}
      [tuple] -> {:ok, player_to_map(tuple)}
    end
  end

  defp player_to_map({{:player, id}, seat, balance}), do: %{id: id, seat: seat, balance: balance}
end
