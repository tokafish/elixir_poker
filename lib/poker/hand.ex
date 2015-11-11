defmodule Poker.Hand do
  use GenServer

  def start(table, players, config \\ [])

  def start(table, players, config) when length(players) > 1 do
    GenServer.start(__MODULE__, [table, players, config])
  end

  def start(_table, _players, _config), do: {:error, :not_enough_players}

  def bet(hand, amount) do
    GenServer.call(hand, {:bet, amount})
  end

  def check(hand) do
    GenServer.call(hand, {:bet, 0})
  end

  def fold(hand) do
    GenServer.call(hand, :fold)
  end

  ### GenServer callbacks
  def init([table, players, config]) do
    seed_random_number_generator

    # Since we're being started by a table process, we need to defer initialization,
    # otherwise we'll deadlock when we try to update player balances with the table
    send self, {:deal, get_blinds(config)}

    {:ok, %{table: table, players: players, phase: :pre_flop, pot: 0, board: []}}
  end

  def handle_info({:deal, {small_blind, big_blind}}, state) do
    state = state |>
      track_initial_positions |>
      post_blinds(small_blind, big_blind) |>
      increment_pot(small_blind + big_blind) |>
      advance_action |>
      advance_action |>
      deal(deck.new)

    update_players(state)

    {:noreply, state}
  end

  defp get_blinds(config) do
    big_blind   = Keyword.get(config, :big_blind, 10)
    small_blind = Keyword.get(config, :small_blind, div(big_blind, 2))
    {small_blind, big_blind}
  end

  defp track_initial_positions(state) do
    players =
      Enum.with_index(state.players) |>
      Enum.map(fn {pid, index} -> %{pid: pid, position: index} end)

    Map.put(state, :players, players)
  end

  defp post_blinds(state = %{players: [small,big|remaining]}, small_blind, big_blind) do
    players = [
      Map.put(small, :to_call, big_blind - small_blind),
      Map.put(big, :to_call, 0)|
      Enum.map(remaining, &(Map.put(&1, :to_call, big_blind)))
    ]

    :ok = Poker.Table.update_balance(state.table, small.pid, -small_blind)
    :ok = Poker.Table.update_balance(state.table, big.pid, -big_blind)

    Map.put(state, :players, players)
  end

  defp deal(state, deck) do
    {players, deck} = Enum.map_reduce state.players, deck, fn (player, [card_one,card_two|deck]) ->
      {Map.put(player, :hand, [card_one, card_two]), deck}
    end

    state |> Map.put(:players, players) |> Map.put(:deck, deck)
  end

  def handle_call(_, {player, _}, state = %{players: [%{pid: another_player}|_]}) when player != another_player do
    {:reply, {:error, :not_active}, state}
  end

  def handle_call({:bet, amount}, _, state = %{players: [%{to_call: to_call}|_]}) when amount < to_call do
    {:reply, {:error, :not_enough}, state}
  end

  # player calls
  def handle_call({:bet, amount}, _, state = %{players: [%{pid: pid, to_call: to_call}|_]}) when amount == to_call do
    case Poker.Table.update_balance(state.table, pid, -amount) do
      :ok ->
        state |> call_bet |> increment_pot(amount) |> advance_action |>
          check_for_phase_end |> update_players |> reply_or_stop
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:bet, amount}, _, state = %{players: [%{pid: pid, to_call: to_call}|_]}) when amount > to_call do
    case Poker.Table.update_balance(state.table, pid, -amount) do
      :ok ->
        state |> call_bet |> increment_pot(amount) |>
          raise_remaining_players(amount - to_call) |> advance_action |>
          check_for_phase_end |> update_players |> reply_or_stop
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:fold, _, state = %{players: [_|remaining_players]}) do
    Map.put(state, :players, remaining_players) |> check_for_phase_end |> update_players |> reply_or_stop
  end

  defp reply_or_stop(state) do
    if Map.has_key?(state, :finished) do
      {:stop, :normal, :ok, state}
    else
      {:reply, :ok, state}
    end
  end

  defp increment_pot(state, amount) do
    Map.update!(state, :pot, &(&1 + amount))
  end

  defp advance_action(state = %{players: [active_player|remaining_players]}) do
    Map.put(state, :players, remaining_players ++ [active_player])
  end

  defp call_bet(state = %{players: [active_player|remaining_players]}) do
    Map.put(state, :players, [Map.delete(active_player, :to_call)|remaining_players])
  end

  defp raise_remaining_players(state = %{players: [active_player|remaining_players]}, amount) do
    raised_players = Enum.map remaining_players, fn player ->
      Map.update(player, :to_call, amount, &(&1 + amount))
    end

    Map.put(state, :players, [active_player|raised_players])
  end

  defp check_for_phase_end(state = %{players: [%{to_call: _}|_]}) do
    state
  end

  defp check_for_phase_end(state) do
    advance_phase(state)
  end

  defp advance_phase(state = %{players: [winner]}) do
    declare_winner(winner, state)
  end

  defp advance_phase(state = %{phase: :pre_flop}) do
    advance_board(state, :flop, 3)
  end

  defp advance_phase(state = %{phase: :flop}) do
    advance_board(state, :turn, 1)
  end

  defp advance_phase(state = %{phase: :turn}) do
    advance_board(state, :river, 1)
  end

  defp advance_phase(state = %{phase: :river}) do
    ranked_players = [{winning_ranking, _, _}|_] =
      state.players |>
      Stream.map(fn player ->
        {ranking, hand} = Poker.Ranking.best_possible_hand(state.board, player.hand)
        {ranking, hand, player}
      end) |>
      Enum.sort |>
      Enum.reverse

    ranked_players |>
      Stream.take_while(fn {ranking, _, _} ->
        ranking == winning_ranking
      end) |>
      Enum.map(&elem(&1, 2)) |>
      declare_winner(state)
  end

  defp advance_board(state, phase, num_cards) do
    players = state.players |>
      Enum.sort_by(&(&1.position)) |>
      Enum.map(fn player -> Map.put(player, :to_call, 0) end)

    {additional_cards, deck} = Enum.split(state.deck, num_cards)

    %{state |
      phase: phase,
      board: state.board ++ additional_cards,
      deck: deck,
      players: players
    }
  end

  defp declare_winner([winner], state), do: declare_winner(winner, state)
  defp declare_winner(winners, state) when is_list(winners) do
    # IO.inspect "The winners are: #{inspect winners}"

    Map.put(state, :finished, true)
  end

  defp declare_winner(winner, state) do
    # IO.inspect "The winner is: #{inspect winner}"

    Poker.Table.update_balance(state.table, winner.pid, state.pot)

    Map.put(state, :finished, true)
  end

  defp update_players(state) do
    [active_player|remaining_players] = state.players

    update_player(active_player, state, true)
    Enum.each remaining_players, &(update_player(&1, state, false))

    state
  end

  defp update_player(player, state, active) do
    hand_state = %{
      hand: player.hand, active: active,
      board: state.board, pot: state.pot
    }
    send player.pid, {:hand_state, hand_state}
  end

  defp seed_random_number_generator do
    <<a::size(32), b::size(32), c::size(32)>> = :crypto.strong_rand_bytes(12)
    :random.seed({a, b, c})
  end

  defp deck do
    Application.get_env(:gen_poker, :deck)
  end
end
