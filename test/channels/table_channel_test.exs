defmodule GenPoker.TableChannelTest do
  use GenPoker.ChannelCase

  alias GenPoker.TableChannel

  @guid "b83de09f-3101-923a-be67-227cedaaa488"

  setup do
    Mocks.Table.start_link(name: {:via, :gproc, {:n, :l, {:table, "test_table"}}})
    {:ok, _, socket} =
      socket("players_socket:#{@guid}", %{player_id: @guid})
      |> subscribe_and_join(TableChannel, "tables:test_table")

    {:ok, socket: socket}
  end

  test "a table can be sat at", %{socket: socket} do
    ref = push socket, "sit", [1]
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  test "a table can be left", %{socket: socket} do
    ref = push socket, "leave", []
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  test "a table can be bought into", %{socket: socket} do
    ref = push socket, "buy_in", [123]
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end

  test "a table can be cashed out from", %{socket: socket} do
    ref = push socket, "cash_out", []
    assert_reply ref, :ok, %{}
    assert_broadcast "update", %{}
  end
end
