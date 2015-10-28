defmodule Poker.Ranking do

# Hand ranks
  @royal_flush     10
  @straight_flush  9
  @four_of_a_kind  8
  @full_house      7
  @flush           6
  @straight        5
  @three_of_a_kind 4
  @two_pair        3
  @one_pair        2
  @high_card       1
  
  def evaluate(cards) do
    cards |> Enum.map(&to_tuple/1) |> Enum.sort |> eval
  end

  def best_possible_hand(board, hand) do
    board ++ hand
      |> combinations(5)
      |> Stream.map(&{evaluate(&1), &1})
      |> Enum.max
  end

  def description({@royal_flush, _}),     do: :royal_flush
  def description({@straight_flush, _}),  do: :straight_flush
  def description({@four_of_a_kind, _}),  do: :four_of_a_kind
  def description({@full_house, _}),      do: :full_house
  def description({@flush, _}),           do: :flush
  def description({@straight, _}),        do: :straight
  def description({@three_of_a_kind, _}), do: :three_of_a_kind
  def description({@two_pair, _}),        do: :two_pair
  def description({@one_pair, _}),        do: :one_pair
  def description({@high_card, _}),       do: :high_card

  defp to_tuple(%Poker.Deck.Card{rank: rank, suit: suit}), do: {rank, suit}

  defp eval([{10, s}, {11, s}, {12, s}, {13, s}, {14, s}]), do: {@royal_flush, nil}

  defp eval([{a, s}, {_b, s}, {_c, s}, {_d, s}, {e, s}]) when e - a == 4, do: {@straight_flush, e}
  defp eval([{2, s}, {3, s}, {4, s}, {5, s}, {14, s}]), do: {@straight_flush, 5}

  defp eval([{a, _}, {a, _}, {a, _}, {a, _}, {b, _}]), do: {@four_of_a_kind, {a,b}}
  defp eval([{b, _}, {a, _}, {a, _}, {a, _}, {a, _}]), do: {@four_of_a_kind, {a,b}}

  defp eval([{a, _}, {a, _}, {a, _}, {b, _}, {b, _}]), do: {@full_house, {a,b}}
  defp eval([{b, _}, {b, _}, {a, _}, {a, _}, {a, _}]), do: {@full_house, {a,b}}

  defp eval([{e, s}, {d, s}, {c, s}, {b, s}, {a, s}]), do: {@flush, {a,b,c,d,e}}

  defp eval([{a, _}, {b, _}, {c, _}, {d, _}, {e, _}])
    when a + 1 == b and b + 1 == c and c + 1 == d and d + 1 == e,
    do: {@straight, e}
  defp eval([{2, _}, {3 , _}, {4 , _}, {5 , _}, {14, _}]), do: {@straight, 5}

  defp eval([{a, _}, {a, _}, {a, _}, {c, _}, {b, _}]), do: {@three_of_a_kind, {a,b,c}}
  defp eval([{c, _}, {a, _}, {a, _}, {a, _}, {b, _}]), do: {@three_of_a_kind, {a,b,c}}
  defp eval([{c, _}, {b, _}, {a, _}, {a, _}, {a, _}]), do: {@three_of_a_kind, {a,b,c}}

  defp eval([{b, _}, {b, _}, {a, _}, {a, _}, {c, _}]), do: {@two_pair, {a,b,c}}
  defp eval([{b, _}, {b, _}, {c, _}, {a, _}, {a, _}]), do: {@two_pair, {a,b,c}}
  defp eval([{c, _}, {b, _}, {b, _}, {a, _}, {a, _}]), do: {@two_pair, {a,b,c}}

  defp eval([{a, _}, {a, _}, {d, _}, {c, _}, {b, _}]), do: {@one_pair, {a,b,c,d}}
  defp eval([{d, _}, {a, _}, {a, _}, {c, _}, {b, _}]), do: {@one_pair, {a,b,c,d}}
  defp eval([{d, _}, {c, _}, {a, _}, {a, _}, {b, _}]), do: {@one_pair, {a,b,c,d}}
  defp eval([{d, _}, {c, _}, {b, _}, {a, _}, {a, _}]), do: {@one_pair, {a,b,c,d}}

  defp eval([{e, _}, {d, _}, {c, _}, {b, _}, {a, _}]), do: {@high_card, {a,b,c,d,e}}

  # Ported from the Erlang
  # http://rosettacode.org/wiki/Combinations#Dynamic_Programming
  def combinations(list, k), do: List.last(all_combinations(list, k))

  defp all_combinations(list, k) do
    accum = [[[]]] ++ List.duplicate([], k)
    Enum.reduce list, accum, fn(x, next) ->
      sub = Enum.take(next, length(next) - 1)
      step = [[]] ++ (for l <- sub, do: (for s <- l, do: [x|s]))
      :lists.zipwith(&:lists.append/2, step, next)
    end
  end
end
