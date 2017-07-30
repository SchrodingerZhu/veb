# written by SchrodingerZhu, provided together with love and good wishes.
defmodule Veb do
  @moduledoc """
  This is an functional implement of the Integer data structure, van Emde Boas tree. As it's in the functional environment, the data structure actually implemented is the RS-vEB tree, which is the normal VEB improved in the time complexity of creation and the space complexity of storage.

  Currently, this module has implemented insert, delete, successor, predecessor operations, the time complexity of which is $O(\log{\log{u}})$, where $u$ is the size of the data universe. And there are also operations like fromList, toList, which are based on those basic operations.

  There exists an limitation of $u$, that is, $u$ must be a power of the $2$. However, a automatical deriving method is written in creating operations, you can simply provide the max value of your data, and then the $u$ will be calculated easily.

  As it is promised in the paper, the space complexity is $O(n)$, where $n$ is the number os your data. According to some randomized tests, the speed of this implement is not bad.
  """

  @typedoc """
  Type t stands for the RS-vEB tree. It is filled with nil and empty map when no element is inserted, and dynamically built as inserting and deleting.
  """
  defstruct log_u: 0, min: nil, max: nil, summary: nil, cluster: %{}
  @type t :: %Veb{log_u: non_neg_integer, min: nil | non_neg_integer, max: nil | non_neg_integer, summary: nil | t, cluster: %{} | %{required(non_neg_integer) => t}}


  use Bitwise

  ## Bitwise calcutating functions, speeding up this implement from the original version provided by Indroduction to Algorithm. 
  defp high(x, log_u) do
    x >>> (log_u >>> 1)
  end

  defp low(x, log_u) do
    tempA = x &&& ((1 <<< ((log_u >>> 1) + 1)) - 1)
    tempB = (1 <<< (log_u >>> 1))
    if tempA < tempB do
      tempA
    else
      bxor(tempA, tempB) 
    end
  end

  defp index(x, y, log_u) do
    (x  <<< (log_u >>> 1)) + y
  end

  #### Currently no need ##############################
  #                                                   #
  # defp upSqrt(log_u), do: 1 <<< ((log_u + 1) >>> 1) #
  #                                                   #
  #                                                   #
  # defp downSqrt(log_u), do: 1 <<< (log_u  >>> 1)    #
  #                                                   #
  #####################################################

  @spec getBits(non_neg_integer) :: non_neg_integer
  @doc """
  Return the count of the valid binary bits of the given number.
  """
  def getBits(0), do: 0
  def getBits(n) when n >= (1 <<< 128), do: __getBits(n >>> 128, 128)
  def getBits(n), do: guessBits(n, 0, 128, 128)

  defp __getBits(0, ans), do: ans
  defp __getBits(n, ans) when n >= (1 <<< 128), do: __getBits(n >>> 128, 128 + ans)
  defp __getBits(n, ans), do: __getBits(0, ans + guessBits(n, 0, 128, 128))
  
  defp guessBits(_, l, r, ans) when l > r, do: ans
  defp guessBits(n, l, r, ans) do
    mid = (l + r) >>> 1;
    if(n >>> mid == 0) do
      guessBits(n, l, mid - 1, mid)
    else
      guessBits(n, mid + 1, r, ans)
    end
  end

  @spec max(nil | t) :: nil | non_neg_integer
  @doc """
  Return the max element of a RS-vEB tree, or nil when given with the empty tree or nil
  """
  def max(nil) do
    nil
  end
  def max(v) do
    v.max
  end

  @spec min(nil | t) :: nil | non_neg_integer
  @doc """
  Return the max element of a RS-vEB tree, or nil when given the empty tree or nil
  """
  def min(nil) do
    nil
  end
  def min(v) do
    v.min
  end

  @spec member?(t, non_neg_integer) :: true | false
  @doc """
  Check whether the given element is in the given tree.
  """
  def member?(v, x) do
    cond do
      v == nil -> false
      x == v.min || x == v.max -> true
      v.log_u == 1 -> false
      true -> member?(v.cluster[high(x, v.log_u)], low(x, v.log_u))
    end
  end

  ## This code block is filled with functions used in the insert method.
  defp emInsert(v, x) do
    %Veb{v | min: x, max: x}
  end

  defp insProcessOne({v, x}) do
    if x < v.min do
      {%Veb{v | min: x}, v.min}
    else
      {v, x}
    end
  end

  defp insProcessThree({v, x}) do
    if x > v.max do
      %Veb{v | max: x}
    else
      v
    end
  end

  defp checkPos(v, pos) do
    case v.cluster[pos] do
      nil -> %Veb{v | cluster: v.cluster |> Map.put_new(pos, %Veb{__struct__() | log_u: v.log_u >>> 1})}
      _ -> v
    end
  end

  defp checkSummary(v) do
    case v.summary do
      nil -> %Veb{v | summary: %Veb{log_u: (v.log_u + 1) >>> 1, min: nil, max: nil, summary: nil, cluster: %{}}}
      _ -> v
    end
  end

  defp insProcessTwo({v, x}) do
    if v.log_u == 1 do
      {v, x}
    else
      newV = v |> checkPos(high(x, v.log_u)) |> checkSummary()
      if min(newV.cluster[high(x, v.log_u)]) == nil do
        {%Veb{newV | summary: insert_unsafe(newV.summary, high(x, v.log_u)), cluster: %{newV.cluster | high(x, v.log_u) => emInsert(newV.cluster[high(x, v.log_u)], low(x, v.log_u))}}, x}
      else
        {%Veb{newV | cluster: %{newV.cluster | high(x, v.log_u) => insert_unsafe(newV.cluster[high(x, v.log_u)], low(x, v.log_u))}}, x}
      end
    end
  end

  @spec new(non_neg_integer, :by_max | :by_u) :: t
  @doc """
  Create a tree, using the given $u$, or deriving $u$ from the given max value. The second mode is set as default. You can change the mode by providing the atom.
  """
  def new(limit, mode \\ :by_max) do
    case mode do
      :by_max -> %Veb{__struct__() | log_u: getBits(limit)}
      :by_u -> %Veb{__struct__() | log_u: getBits(limit) - 1}
    end
  end

  @spec insert_unsafe(t, non_neg_integer) :: t
  @doc """
  Insert an element unsafely, you should make sure that the element is within the bound and without repeats.
  """
  def insert_unsafe(v, x) do
    if v. min == nil do
      emInsert(v, x)
    else
      {v, x} |> insProcessOne() |> insProcessTwo() |> insProcessThree()
    end
  end

  @spec insert(t, non_neg_integer) :: t | :error
  @doc """
  Insert an element with overflow and repeating check.
  """
  def insert(v, x) do
    cond do
      x >= (1 <<< v.log_u) || x < 0 -> :error
      member?(v, x) -> v
      true -> insert_unsafe(v, x)
    end
  end

  @spec fromList(list, non_neg_integer, :auto | :by_max | :by_u) :: t
  @doc """
  Create a tree from a list. Similarily as the new(), you can change the mode by providing the atom. \":auto\" is set as default, which is to enum the list to find the max value.
  """
  def fromList(list, limit \\ 0, mode \\ :auto) do
    case mode do
      :auto -> List.foldl(list, new(Enum.max(list), :by_max), fn x, acc -> Veb.insert(acc, x) end)
      mode -> List.foldl(list, new(limit, mode), fn x, acc -> Veb.insert(acc, x) end)
    end
  end

  @spec succ(t | nil, non_neg_integer) :: non_neg_integer | nil
  @doc """
  Return the successor element or return nil when the tree is nil or empty or the required element is not exist.
  """
  def succ(v, x) do
    cond do
      v == nil || v.min == nil || x >= v.max  -> nil
      v.log_u == 1 ->
        if x == 0 && v.max == 1 do
          1
        else
          nil
        end
      x < v.min -> v.min
      true ->
        max_low = max(v.cluster[high(x, v.log_u)])
        if max_low != nil && low(x, v.log_u) < max_low do
          offset = succ(v.cluster[high(x, v.log_u)], low(x, v.log_u))
          index(high(x, v.log_u), offset, v.log_u)
        else
          succ_cluster = succ(v.summary, high(x, v.log_u))
          if succ_cluster == nil do
            nil
          else
            offset = min(v.cluster[succ_cluster])
            index(succ_cluster, offset, v.log_u)
          end
        end
    end
  end

  @spec pred(t | nil, non_neg_integer) :: non_neg_integer | nil
  @doc """
  Return the predecessor element or return nil when the tree is nil or empty or the required element is not exist.
  """
  def pred(v, x) do
    cond do
      v == nil || v.max == nil || x <= v.min -> nil
      v.log_u == 1 ->
        if x == 1 && v.min == 0 do
          0
        else
          nil
        end
      x > v.max -> v.max
      true ->
        min_low = min(v.cluster[high(x, v.log_u)])
        if min_low != nil && low(x, v.log_u) > min_low do
          offset = pred(v.cluster[high(x, v.log_u)], low(x, v.log_u))
          index(high(x, v.log_u), offset, v.log_u)
        else
          pred_cluster = pred(v.summary, high(x, v.log_u))
          if pred_cluster == nil do
            if v.min != nil && x > v.min do
              v.min
            else
              nil
            end
          else
            offset = max(v.cluster[pred_cluster])
            index(pred_cluster, offset, v.log_u)
          end
        end
    end
  end

  ## This code block is filled with functions used by delete operations.
  defp delProcessOne({v, x}) do
    if x == v.min do
      first_cluster = min(v.summary)
      newX = index(first_cluster, min(v.cluster[first_cluster]), v.log_u)
      newV = %Veb{v | min: newX}
      {newV, newX}
    else
      {v, x}
    end
  end

  defp delProcessTwo({v, x}) do
    {%Veb{v | cluster: %{v.cluster | high(x, v.log_u) => delete(v.cluster[high(x, v.log_u)], low(x, v.log_u))}} ,x}
  end

  defp delProcessThree({v, x}) do
    cond do
      min(v.cluster[high(x, v.log_u)]) == nil -> {v, x} |> delSubProcessOne() |> delSubProcessTwo()
      x == v.max -> %Veb{v | max: index(high(x, v.log_u), max(v.cluster[high(x, v.log_u)]), v.log_u)}
      true -> v
    end
  end

  defp delSubProcessOne({v, x}) do
    {%Veb{v | summary: delete(v.summary, high(x, v.log_u))}, x}
  end

  defp delSubProcessTwo({v, x}) do
    if x == v.max do
      summary_max = max(v.summary)
      if summary_max == nil do
        %Veb{v | max: v.min}
      else
        %Veb{v | max: index(summary_max, max(v.cluster[summary_max]), v.log_u)}
      end
    else
      v
    end
  end

  @spec delete(t | nil, non_neg_integer) :: t | nil
  @doc """
  Delete the given element from the tree with check.
  """
  def delete(v, x) do
    case member?(v, x) do
      true -> delete_unsafe(v, x)
      false -> v
    end
  end

  @spec delete_unsafe(t | nil, non_neg_integer) :: t | nil
  @doc """
  Delete the given element from the tree unsafely. You should make sure that the element is in the tree.
  """
  def delete_unsafe(nil, _x), do: nil
  def delete_unsafe(v, x) do
    cond do
      v.min == v.max && v.min == x -> nil
      v.log_u == 1 ->
        if x == 0 do
          %Veb{v | min: 1, max: 1}
        else
          %Veb{v | min: 0, max: 0}
        end
      true ->
        {v, x} |> delProcessOne() |> delProcessTwo() |> delProcessThree()
    end
  end

  @spec toList(t) :: list
  @doc """
  Create a list from a tree. Note that nil tree is not supported and will cause runtime error.
  """
  def toList(v) do
    __toList(v, v.max, [])
  end
  defp __toList(_v, nil, list), do: list
  defp __toList(v, cur, list), do: __toList(v, Veb.pred(v, cur), [cur | list])

  defimpl Inspect do
    def inspect(v, _opt \\ []) do
      "#Veb<[maxValueLimit: "
      <> Kernel.inspect((1 <<< v.log_u) - 1)
      <> ", data: "
      <> Kernel.inspect(Veb.toList(v))
      <> "]>"
    end
  end
end

defmodule VebMap do
  use Bitwise

  @behaviour Access
  @type data :: {non_neg_integer, any}
  defstruct map: %{}, tree: Veb.__struct__

  def new(limit, mode \\ :by_max) do
    %VebMap{map: %{}, tree: Veb.new(limit, mode)}
  end

  def has_key?(vm, key) do
    Map.has_key?(vm.map, key)
  end

  def put_new(vm, key, value) do
    if has_key?(vm, key) do
      vm
    else
      %VebMap{vm | map: Map.put_new(vm.map, key, value), tree: Veb.insert(vm.tree, key)}
    end
  end

  def delete(vm, key) do
    if has_key?(vm, key) do
      %VebMap{vm | map: Map.delete(vm.map, key), tree: Veb.delete(vm.tree, key)}
    else
      vm
    end
  end

  def fetch!(vm, key) do
    Map.fetch!(vm.map, key)
  end

  def fetch(vm, key) do
    Map.fetch(vm.map, key)
  end

  def equal?(vm1, vm2) do
    Map.equal?(vm1.map, vm2.map)
  end

  def drop(vm, []), do: vm
  def drop(vm, [head | tail]), do: drop(delete(vm, head), tail)

  def values(vm) do
    Map.values(vm.map)
  end

  def update!(vm, key, fun) do
    %VebMap{vm | map: Map.update!(vm.map, key, fun)}
  end

  def update(vm, key, initial, fun) do
    if has_key?(vm, key) do
      update!(vm, key, fun)
    else
      put_new(vm, key, initial)
    end
  end

  def to_list(vm) do
    Map.to_list(vm.map)
  end

  def take(vm, keys) do
    Map.take(vm.map, keys)
  end

  def split(vm, keys) do
    vm.map
    |> Map.split(keys)
    |> (fn {a, b} -> {from_map(a, 1 <<< vm.tree.log_u, :by_u), from_map(b, 1 <<< vm.tree.log_u, :by_u)} end).()
  end
  
  def from_map(map, limit \\ 0, mode \\ :auto) do
    %VebMap{map: map, tree: map |> Map.keys() |> Veb.fromList(limit, mode)}
  end

  def replace!(vm, key, value) do
    %VebMap{vm | map: Map.replace!(vm.map, key, value)}
  end

  def replace(vm, key, value) do
    if has_key?(vm, key) do
      replace!(vm, key, value)
    else
      vm
    end
  end

  def put_new_lazy(vm, key, fun) do
    if has_key?(vm, key) do
      vm
    else
      put_new(vm, key, fun.())
    end
  end

  def put(vm, key, value) do
    %VebMap{map: Map.put(vm.map, key, value), tree: Veb.insert(vm.tree, key)}
  end

  def pop(vm, key, default \\ nil) do
    if has_key?(vm, key) do
      {ele, new_map} = Map.pop(vm.map, key, default)
      {ele, %VebMap{map: new_map, tree: Veb.delete(vm.tree, key)}}
    else
      {default, vm}
    end
  end

  def pop_lazy(vm, key, fun) do
    if has_key?(vm, key) do
      {ele, new_map} = Map.pop(vm.map, key, fun)
      {ele, %VebMap{map: new_map, tree: Veb.delete(vm.tree, key)}}
    else
      {fun.(), vm}
    end
  end
  ## not right
  def merge(vm1, vm2, callback) do
    new_map = Map.merge(vm1, vm2, callback)
    from_map(new_map, 1 <<< max(vm1.tree.log_u, vm2.tree.log_u), :by_u)
  end
  ## not right
  def merge(vm1, vm2) do
    new_map = Map.merge(vm1, vm2)
    from_map(new_map, 1 <<< max(vm1.tree.log_u, vm2.tree.log_u), :by_u)
  end

  def keys(vm) do
    Map.keys(vm.map)
  end

  def get(vm, key, default \\ nil) do
    Map.get(vm.map, key, default)
  end

  def get_lazy(vm, key, fun) do
    Map.get_lazy(vm.map, key, fun)
  end

  ## Not Right

  def get_and_update!(vm, key, fun) do
    %VebMap{vm | map: Map.get_and_update!(vm.map, key, fun)}
  end

  def get_and_update(vm, key, fun) do
    if has_key?(vm, key) do
      if vm |> fetch!(key) |> fun.() == :pop do
        pop(vm, key)
      else
        get_and_update!(vm, key, fun)
      end
    else
      pop(vm, key)
    end
  end




  defimpl Inspect do
    def inspect(vm, _opt \\ []) do
      "VebMap<" <> Kernel.inspect(vm.map) <> "%>"
    end
  end
end


