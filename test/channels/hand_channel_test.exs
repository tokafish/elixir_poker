defmodule GenPoker.HandChannelTest do
  use GenPoker.ChannelCase
  alias GenPoker.HandChannel

  defmodule MockHand do
    use GenServer

    def start_link(state, opts \\ []) do
      GenServer.start_link(__MODULE__, state, opts)
    end

    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end

    def handle_call(_msg, _from, state) do
      {:reply, :ok, state}
    end
  end

  defmacro refute_push(event, payload, timeout \\ 100) do
    quote do
      refute_receive %Phoenix.Socket.Message{
                        event: unquote(event),
                        payload: unquote(payload)}, unquote(timeout)
    end
  end

  @id "one"

  def start_hand(state) do
    MockHand.start_link(state, name: {:via, :gproc, {:n, :l, {:hand, "test_hand"}}})
  end

  setup %{state: state} do
    start_hand(state)
    {:ok, _, socket} =
      socket("players_socket:#{@id}", %{player_id: @id})
      |> subscribe_and_join(HandChannel, "hands:test_hand")

    {:ok, socket: socket}
  end

  @tag state: %{players: []}
  test "a hand can be bet", %{socket: socket} do
    ref = push socket, "bet", [100]
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  @tag state: %{players: []}
  test "a hand can be checked", %{socket: socket} do
    ref = push socket, "check", []
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  @tag state: %{players: []}
  test "a hand can be folded", %{socket: socket} do
    ref = push socket, "fold", []
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  @tag state: %{players: [
    %{id: @id, hand: [:card_one, :card_two]},
    %{id: "another", hand: [:card_three, :card_four]},
  ]}
  test "updates do not include the hands of the non-active player" do
    # refute_push "update", %{players: [%{id: @id}, %{id: "another", hand: _hand}]}
    assert_push "update", %{players: [%{id: @id, hand: [:card_one, :card_two]}, %{id: "another"}]}
  end
end
