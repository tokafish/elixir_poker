defmodule GenPoker.HandChannel do
  use GenPoker.Web, :channel
  alias Poker.Hand

  intercept ["update"]

  def join("hands:" <> hand, _payload, socket) do
    send self, :after_join
    {:ok, assign(socket, :hand, hand)}
  end

  def handle_in(command, payload, socket) when command in ~w(bet check fold) do
    hand = Hand.whereis(socket.assigns.hand)
    arguments = [hand, socket.assigns.player_id] ++ payload
    result = apply(Hand, String.to_atom(command), arguments)
    if result == :ok do
      broadcast! socket, "update", Hand.get_state(hand)
    end
    {:reply, result, socket}
  end

  def handle_info(:after_join, socket) do
    state = socket.assigns.hand |> Hand.whereis |> Hand.get_state |> hide_other_hands(socket)
    push socket, "update", state
    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  def handle_out("update", state, socket) do
    push socket, "update", hide_other_hands(state, socket)
    {:noreply, socket}
  end

  defp hide_other_hands(state, socket) do
    player_id = socket.assigns.player_id
    hide_hand_if_current_player = fn
      %{id: ^player_id} = player -> player
      player -> Map.delete(player, :hand)
    end

    update_in(state.players, fn players ->
      Enum.map(players, hide_hand_if_current_player)
    end)
  end
end
