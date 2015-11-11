defmodule Mocks.StackedDeck do
  def stack(cards) do
    Agent.start_link(fn -> cards end, name: __MODULE__)
  end

  def new do
    Agent.get(__MODULE__, &(&1))
  end
end
