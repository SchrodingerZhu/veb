defmodule VebTest do
  use ExUnit.Case
  doctest Veb
  @random_max 100000
  @size 1000
  defp gen_data() do
    (fn -> Enum.random(0..@random_max) end)
    |> Stream.repeatedly()
    |> Enum.take(@size)
    |> Enum.sort()
    |> Enum.uniq()
  end
  
  test "insert and pred by from_list and to_list" do
    a =
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      |> Enum.map(fn _ -> gen_data() end)
    b =
      a
      |> Enum.map(fn l -> Veb.from_list(l) end)
      |> Enum.map(fn v -> Veb.to_list(v) end)
    assert a == b
  end

  test "member?" do
    indexes = (fn -> Enum.random(0..@random_max) end) |> Stream.repeatedly() |> Enum.take(@size)
    data = gen_data() 
    veb = Veb.from_list(data)
    a = Enum.map(indexes, fn x -> Enum.member?(data, x) end)
    b = Enum.map(indexes, fn x -> Veb.member?(veb, x) end)
    assert a == b
  end

  defp to_list_with_succ(_v, nil, ans) do
    Enum.reverse ans
  end
  defp to_list_with_succ(v, x, cur) do
    to_list_with_succ(v, Veb.succ(v, x), [x | cur])
  end
  test "succ?" do
    a =
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
      |> Enum.map(fn _ -> gen_data() end)
    b =
      a
      |> Enum.map(fn x -> Veb.from_list(x) end)
      |> Enum.map(fn x -> to_list_with_succ(x, x.min, []) end)
    assert a == b
  end
  test "delete" do
    indexes = (fn -> Enum.random(0..@random_max) end) |> Stream.repeatedly() |> Enum.take(@size)
    data = gen_data() 
    veb = Veb.from_list(data)
    b = List.foldl(indexes, veb, fn (x, acc) -> Veb.delete(acc, x) end) |> Veb.to_list()
    assert (data -- indexes)  == b
  end
  test "slice" do
    data = gen_data()
    veb = Veb.from_list(data)
    res =
      Stream.repeatedly(fn -> {Enum.random(0..10000), Enum.random(0..1000)} end)
      |> Enum.take(1000)
      |> Enum.map(fn {a, b} -> Enum.slice(veb, a, b) == Enum.slice(data, a, b) end)
    |> Enum.reduce(true, &(&1 && &2))
    assert res
  end

end
