defmodule Poker.Deck do
  defmodule Card do
    @type suit :: :clubs | :diamonds | :hearts | :spades
    @type rank :: 2..14
    @type t :: %__MODULE__{rank: rank, suit: suit}

    defstruct [:rank, :suit]

    def from_string(<< rank :: size(8), suit :: size(8) >>) do
      %__MODULE__{ rank: rank_from_char(rank), suit: suit_from_char(suit) }
    end

    defp rank_from_char(?A), do: 14
    defp rank_from_char(?K), do: 13
    defp rank_from_char(?Q), do: 12
    defp rank_from_char(?J), do: 11
    defp rank_from_char(?T), do: 10
    defp rank_from_char(rank) when rank >= ?2 and rank <= ?9, do: rank - ?0

    defp suit_from_char(?s), do: :spades
    defp suit_from_char(?c), do: :clubs
    defp suit_from_char(?h), do: :hearts
    defp suit_from_char(?d), do: :diamonds
  end

  @spec new() :: [Card.t]
  def new do
    for rank <- ranks, suit <- suits do
      %Card{rank: rank, suit: suit}
    end |> Enum.shuffle
  end

  defp ranks, do: Enum.to_list(2..14)
  defp suits, do: [:spades, :clubs, :hearts, :diamonds]
end

defimpl String.Chars, for: Poker.Deck.Card do
  def to_string(%Poker.Deck.Card{rank: rank, suit: suit}) do
    "#{rank_to_string(rank)}#{suit_to_string(suit)}"
  end

  defp rank_to_string(rank) when rank < 10, do: rank
  defp rank_to_string(10), do: "T"
  defp rank_to_string(11), do: "J"
  defp rank_to_string(12), do: "Q"
  defp rank_to_string(13), do: "K"
  defp rank_to_string(14), do: "A"

  defp suit_to_string(suit) do
    suit |> Atom.to_string |> String.first
  end
end
