defmodule Poker.Ranking do
  def evaluate(cards) do
    cards |> Enum.map(&to_tuple/1) |> Enum.sort |> eval
  end

  def best_possible_hand(board, hand) do
    board ++ hand
      |> combinations(5)
      |> Stream.map(&{evaluate(&1), &1})
      |> Enum.max
  end

  def description({10, _}), do: :royal_flush
  def description({9, _}),  do: :straight_flush
  def description({8, _}),  do: :four_of_a_kind
  def description({7, _}),  do: :full_house
  def description({6, _}),  do: :flush
  def description({5, _}),  do: :straight
  def description({4, _}),  do: :three_of_a_kind
  def description({3, _}),  do: :two_pair
  def description({2, _}),  do: :one_pair
  def description({1, _}),  do: :high_card

  defp to_tuple(%Poker.Deck.Card{rank: rank, suit: suit}), do: {rank, suit}

  defp eval([{10, s}, {11, s}, {12, s}, {13, s}, {14, s}]), do: {10, nil}

  defp eval([{a, s}, {_b, s}, {_c, s}, {_d, s}, {e, s}]) when e - a == 4, do: {9, e}
  defp eval([{2, s}, {3, s}, {4, s}, {5, s}, {14, s}]), do: {9, 5}

  defp eval([{a, _}, {a, _}, {a, _}, {a, _}, {b, _}]), do: {8, {a,b}}
  defp eval([{b, _}, {a, _}, {a, _}, {a, _}, {a, _}]), do: {8, {a,b}}

  defp eval([{a, _}, {a, _}, {a, _}, {b, _}, {b, _}]), do: {7, {a,b}}
  defp eval([{b, _}, {b, _}, {a, _}, {a, _}, {a, _}]), do: {7, {a,b}}

  defp eval([{e, s}, {d, s}, {c, s}, {b, s}, {a, s}]), do: {6, {a,b,c,d,e}}

  defp eval([{a, _}, {b, _}, {c, _}, {d, _}, {e, _}])
    when a + 1 == b and b + 1 == c and c + 1 == d and d + 1 == e,
    do: {5, e}
  defp eval([{2, _}, {3 , _}, {4 , _}, {5 , _}, {14, _}]), do: {5, 5}

  defp eval([{a, _}, {a, _}, {a, _}, {c, _}, {b, _}]), do: {4, {a,b,c}}
  defp eval([{c, _}, {a, _}, {a, _}, {a, _}, {b, _}]), do: {4, {a,b,c}}
  defp eval([{c, _}, {b, _}, {a, _}, {a, _}, {a, _}]), do: {4, {a,b,c}}

  defp eval([{b, _}, {b, _}, {a, _}, {a, _}, {c, _}]), do: {3, {a,b,c}}
  defp eval([{b, _}, {b, _}, {c, _}, {a, _}, {a, _}]), do: {3, {a,b,c}}
  defp eval([{c, _}, {b, _}, {b, _}, {a, _}, {a, _}]), do: {3, {a,b,c}}

  defp eval([{a, _}, {a, _}, {d, _}, {c, _}, {b, _}]), do: {2, {a,b,c,d}}
  defp eval([{d, _}, {a, _}, {a, _}, {c, _}, {b, _}]), do: {2, {a,b,c,d}}
  defp eval([{d, _}, {c, _}, {a, _}, {a, _}, {b, _}]), do: {2, {a,b,c,d}}
  defp eval([{d, _}, {c, _}, {b, _}, {a, _}, {a, _}]), do: {2, {a,b,c,d}}

  defp eval([{e, _}, {d, _}, {c, _}, {b, _}, {a, _}]), do: {1, {a,b,c,d,e}}

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
