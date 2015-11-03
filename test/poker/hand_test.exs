defmodule MockPlayer do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, [self, name])
  end

  defmacro as_player(player, do: block) do
    quote do
      func = fn ->
        unquote(block)
      end
      MockPlayer.perform(unquote(player), func)
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

defmodule Test.StackedDeck do
  def new do
    "As Jd " <> # player one's cards
    "Jc Tc " <> # player two's cards
    "Js Ts " <> # player three's cards
    "Ad 9h 8s Jh Qd" |> # the board
    String.split |>
    Enum.map(&Poker.Deck.Card.from_string/1)
  end
end

defmodule Poker.HandTest do
  use ExUnit.Case, async: true

  import MockPlayer, only: [as_player: 2]

  setup do
    players = Enum.map ~w(player_one player_two player_three), fn (name) ->
      {:ok, player} = MockPlayer.start_link(String.to_atom(name))
      player
    end

    {:ok, [players: players]}
  end

  test "betting, raising, and folding", %{players: players} do
    [player_one, player_two, player_thr] = players

    {:ok, hand} = Poker.Hand.start_link(players)

    # Pre-Flop
    assert_receive {:player_one, {:hand_state, %{active: false, board: [], pot: 15}}}
    assert_receive {:player_two, {:hand_state, %{active: false, board: [], pot: 15}}}
    assert_receive {:player_three, {:hand_state, %{active: true, board: [], pot: 15}}}

    as_player player_thr, do: {:error, :not_enough} = Poker.Hand.bet(hand, 5)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 10)
    assert_receive {:player_one, {:hand_state, %{active: true, board: [], pot: 25}}}
    assert_receive {:player_two, {:hand_state, %{active: false, board: [], pot: 25}}}
    assert_receive {:player_three, {:hand_state, %{active: false, board: [], pot: 25}}}

    as_player player_thr, do: {:error, :not_active} = Poker.Hand.bet(hand, 10)
    as_player player_one, do: :ok = Poker.Hand.bet(hand, 5)
    assert_receive {:player_one, {:hand_state, %{active: false, board: [], pot: 30}}}
    assert_receive {:player_two, {:hand_state, %{active: true, board: [], pot: 30}}}
    assert_receive {:player_three, {:hand_state, %{active: false, board: [], pot: 30}}}

    as_player player_two, do: :ok = Poker.Hand.check(hand)

    # Flop
    as_player player_one, do: :ok = Poker.Hand.check(hand)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 25)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_one, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 25)

    # Turn
    as_player player_one, do: :ok = Poker.Hand.check(hand)
    as_player player_two, do: :ok = Poker.Hand.check(hand)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_one, do: :ok = Poker.Hand.fold(hand)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 50)

    # River
    as_player player_two, do: :ok = Poker.Hand.check(hand)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
    as_player player_two, do: :ok = Poker.Hand.bet(hand, 100)
    as_player player_thr, do: :ok = Poker.Hand.bet(hand, 50)
  end
end
