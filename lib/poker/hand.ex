defmodule Poker.Hand do
  use GenServer

  def start_link(hand, table, config \\ [])  do
    GenServer.start_link(__MODULE__, [hand, table, config], name: via_tuple(hand))
  end

  defp via_tuple(hand), do: {:via, :gproc, {:n, :l, {:hand, hand}}}

  def whereis(hand) do
    :gproc.whereis_name({:n, :l, {:hand, hand}})
  end

  def deal(hand, players) when length(players) > 1 do
    GenServer.cast(hand, {:deal, players})
  end

  def deal(_hand, _players), do: {:error, %{reason: :not_enough_players}}

  def bet(hand, player, amount) do
    GenServer.call(hand, {:bet, player, amount})
  end

  def check(hand, player) do
    GenServer.call(hand, {:bet, player, 0})
  end

  def fold(hand, player) do
    GenServer.call(hand, {:fold, player, nil})
  end

  def get_state(hand) do
    GenServer.call(hand, :get_state)
  end

  ### GenServer callbacks
  def init([hand, table, config]) do
    seed_random_number_generator

    {
      :ok,
      %{hand: hand, table: table, phase: :pre_flop, pot: 0, board: [], blinds: get_blinds(config)}
    }
  end

  def handle_cast({:deal, players}, state) do
    {small_blind, big_blind} = state.blinds

    state = Map.put(state, :players, players) |>
      track_initial_positions |>
      post_blinds(small_blind, big_blind) |>
      increment_pot(small_blind + big_blind) |>
      advance_action |>
      advance_action |>
      deal_hands(deck.new)

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
      Enum.map(fn {id, index} -> %{id: id, position: index} end)

    Map.put(state, :players, players)
  end

  defp post_blinds(state = %{players: [small,big|remaining]}, small_blind, big_blind) do
    players = [
      Map.put(small, :to_call, big_blind - small_blind),
      Map.put(big, :to_call, 0)|
      Enum.map(remaining, &(Map.put(&1, :to_call, big_blind)))
    ]

    :ok = Poker.Table.update_balance(state.table, small.id, -small_blind)
    :ok = Poker.Table.update_balance(state.table, big.id, -big_blind)

    Map.put(state, :players, players)
  end

  defp deal_hands(state, deck) do
    {players, deck} = Enum.map_reduce state.players, deck, fn (player, [card_one,card_two|deck]) ->
      {Map.put(player, :hand, [card_one, card_two]), deck}
    end

    state |> Map.put(:players, players) |> Map.put(:deck, deck)
  end

  def handle_call({_, player, _}, _, state = %{players: [%{id: another_player}|_]}) when player != another_player do
    {:reply, {:error, %{reason: :not_active}}, state}
  end

  def handle_call({:bet, _, amount}, _, state = %{players: [%{to_call: to_call}|_]}) when amount < to_call do
    {:reply, {:error, %{reason: :not_enough}}, state}
  end

  # player calls
  def handle_call({:bet, player, amount}, _, state = %{players: [%{to_call: to_call}|_]}) when amount == to_call do
    case Poker.Table.update_balance(state.table, player, -amount) do
      :ok ->
        state |> call_bet |> increment_pot(amount) |> advance_action |>
          check_for_phase_end |> reply_or_stop
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:bet, player, amount}, _, state = %{players: [%{to_call: to_call}|_]}) when amount > to_call do
    case Poker.Table.update_balance(state.table, player, -amount) do
      :ok ->
        state |> call_bet |> increment_pot(amount) |>
          raise_remaining_players(amount - to_call) |> advance_action |>
          check_for_phase_end |> reply_or_stop
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:fold, _, _}, _, state = %{players: [_|remaining_players]}) do
    Map.put(state, :players, remaining_players) |> check_for_phase_end |> reply_or_stop
  end

  def handle_call(:get_state, _, state) do
    players_with_active_flag =
      state.players |>
      Enum.with_index |>
      Enum.map(fn {player, index} ->
        active = index == 0
        Map.put(player, :active, active)
      end)

    reply =
      state |>
      Map.take([:phase, :board, :pot, :players]) |>
      Map.put(:players, players_with_active_flag)

    {:reply, reply, state}
  end

  defp reply_or_stop(state) do
    if Map.has_key?(state, :finished) do
      Poker.Table.hand_finished(state.table)
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

    Poker.Table.update_balance(state.table, winner.id, state.pot)

    Map.put(state, :finished, true)
  end

  defp seed_random_number_generator do
    <<a::size(32), b::size(32), c::size(32)>> = :crypto.strong_rand_bytes(12)
    :random.seed({a, b, c})
  end

  defp deck do
    Application.get_env(:gen_poker, :deck)
  end
end
