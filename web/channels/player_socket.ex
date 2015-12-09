defmodule GenPoker.PlayerSocket do
  use Phoenix.Socket

  channel "tables:*", GenPoker.TableChannel
  channel "hands:*", GenPoker.HandChannel

  transport :websocket, Phoenix.Transports.WebSocket

  def connect(%{"playerId" => player_id}, socket) do
    {:ok, assign(socket, :player_id, player_id)}
  end

  def id(socket), do: "players_socket:#{socket.assigns.player_id}"
end
