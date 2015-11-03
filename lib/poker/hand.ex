defmodule Poker.Hand do
  use GenServer

  def start_link(players, config \\ [])

  def start_link(players, config) when length(players) > 1 do
    GenServer.start_link(__MODULE__, [players, config])
  end

  def start_link(_players, _config), do: {:error, :not_enough_players}

  def active_player(hand) do
    GenServer.call(hand, :active_player)
  end

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
  def init([players, config]) do
    <<a::size(32), b::size(32), c::size(32)>> = :crypto.rand_bytes(12)
    :random.seed({a, b, c})

    {small_blind_amount, big_blind_amount} = get_blinds(config)
    [small_blind_player, big_blind_player|remaining_players] = players

    to_act =
      Enum.map(remaining_players, &{&1, big_blind_amount}) ++
      [
        {small_blind_player, big_blind_amount - small_blind_amount},
        {big_blind_player, 0}
      ]

    {hands, deck} = deal(deck.new, players)

    state = %{
      phase: :pre_flop,
      players: players,
      pot: small_blind_amount + big_blind_amount,
      board: [],
      hands: hands,
      deck: deck,
      to_act: to_act
    }

    update_players(state)

    {:ok, state}
  end

  def handle_call({:bet, _}, {player, _}, state = %{to_act: [{another_player, _}|_]}) when player != another_player do
    {:reply, {:error, :not_active}, state}
  end

  def handle_call({:bet, amount}, _from, state = %{to_act: [{_, to_call}|_]}) when amount < to_call do
    {:reply, {:error, :not_enough}, state}
  end

  # player calls, no other players need to act
  def handle_call({:bet, amount}, _from, state = %{to_act: [{_, to_call}]}) when amount == to_call do
    updated_state = update_in(state.pot, &(&1 + amount)) |>
      advance_phase |>
      update_players

    {:reply, :ok, updated_state}
  end

  # player calls, more players need to act
  def handle_call({:bet, amount}, _from, state = %{to_act: [{_, to_call}|to_act]}) when amount == to_call do
    updated_state = update_in(state.pot, &(&1 + amount)) |>
      put_in([:to_act], to_act) |>
      update_players

    {:reply, :ok, updated_state}
  end

  # player raises
  def handle_call({:bet, amount}, _from, state = %{to_act: [{player, to_call}|remaining_actions]}) when amount > to_call do
    raised_amount = amount - to_call

    previous_callers = state.players |>
      Stream.concat(state.players) |>
      Stream.drop_while(&(&1 != player)) |>
      Stream.drop(1 + length(remaining_actions)) |>
      Stream.take_while(&(&1 != player))

    to_act = Enum.map(remaining_actions, fn {player, to_call} ->
      {player, to_call + raised_amount}
    end) ++ Enum.map(previous_callers, fn player ->
      {player, raised_amount}
    end)

    updated_state = %{state | to_act: to_act, pot: state.pot + amount} |> update_players

    {:reply, :ok, updated_state}
  end

  # player folds, no other players need to act
  def handle_call(:fold, {player, _}, state = %{to_act: [{player, _}]}) do
    updated_state = state |>
      update_in([:players], &(List.delete(&1, player))) |>
      advance_phase |>
      update_players
    {:reply, :ok, updated_state}
  end

  # player folds, more players need to act
  def handle_call(:fold, {player, _}, state = %{to_act: [{player, _}|to_act]}) do
    updated_state = state |>
      update_in([:players], &(List.delete(&1, player))) |>
      put_in([:to_act], to_act) |>
      update_players

    {:reply, :ok, updated_state}
  end

  def handle_call(:fold, _from, state) do
    {:reply, {:error, :not_active}, state}
  end

  defp get_blinds(config) do
    big_blind   = Keyword.get(config, :big_blind, 10)
    small_blind = Keyword.get(config, :small_blind, div(big_blind, 2))
    {small_blind, big_blind}
  end

  defp deal(deck, players) do
    {hands, deck} = Enum.map_reduce players, deck, fn (player, [card_one,card_two|deck]) ->
      {{player, [card_one, card_two]}, deck}
    end

    {Enum.into(hands, %{}), deck}
  end

  defp update_players(state) do
    Enum.each state.players, fn (player) ->
      hand = Map.fetch! state.hands, player
      hand_state = %{
        hand: hand,
        active: player_active?(player, state),
        board: state.board,
        pot: state.pot
      }
      send player, {:hand_state, hand_state}
    end

    state
  end

  defp player_active?(player, %{to_act: [{player, _}|_]}), do: true
  defp player_active?(_player, _state), do: false

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
    ranked_players = [{winning_ranking,_}|_] =
      state.players |>
      Stream.map(fn player ->
        {ranking, _} = Poker.Ranking.best_possible_hand(state.board, state.hands[player])
        {ranking, player}
      end) |>
      Enum.sort

    ranked_players |>
      Stream.take_while(fn {ranking, _} ->
        ranking == winning_ranking
      end) |>
      Enum.map(&elem(&1, 1)) |>
      declare_winner(state)

    state
  end

  defp advance_board(state, phase, num_cards) do
    to_act = Enum.map(state.players, &{&1, 0})

    {additional_cards, deck} = Enum.split(state.deck, num_cards)

    %{state |
      phase: phase,
      board: state.board ++ additional_cards,
      deck: deck,
      to_act: to_act
    }
  end

  defp declare_winner([winner], state), do: declare_winner(winner, state)
  defp declare_winner(winners, state) when is_list(winners) do
    IO.inspect "The winners are: #{inspect winners}"

    state
  end

  defp declare_winner(winner, state) do
    IO.inspect "The winner is: #{inspect winner}"

    state
  end

  defp deck do
    Application.get_env(:gen_poker, :deck)
  end
end
