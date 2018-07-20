# written by SchrodingerZhu, provided together with love and good wishes.
defmodule Veb.InsertError do
  defexception [:message]
  def exception(reason) do
    %Veb.InsertError{message: "error during inserting: #{reason}"}
  end
end

defmodule Veb.DeleteError do
  defexception [:message]
  def exception(reason) do
    %Veb.DeleteError{message: "error during deleting: #{reason}"}
  end
end

defmodule Veb do
  @moduledoc """
  This is an functional implement of the Integer data structure, van Emde Boas tree. As it's in the functional environment, the data structure actually implemented is the RS-vEB tree, which is the normal VEB improved in the time complexity of creation and the space complexity of storage.

  Currently, this module has implemented insert!, delete, successor, predecessor operations, the time complexity of which is $O(\log{\log{u}})$, where $u$ is the size of the data universe. And there are also operations like from_list, to_list, which are based on those basic operations.

  There exists an limitation of $u$, that is, $u$ must be a power of the $2$. However, a automatical deriving method is written in creating operations, you can simply provide the max value of your data, and then the $u$ will be calculated easily.

  As it is promised in the paper, the space complexity is $O(n)$, where $n$ is the number os your data. According to some randomized tests, the speed of this implement is not bad.
  """

  @typedoc """
  Type t stands for the RS-vEB tree. It is filled with nil and empty map when no element is insert!ed, and dynamically built as insert!ing and deleting.
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

  @spec get_bits(non_neg_integer) :: non_neg_integer
  @doc """
  Return the count of the valid binary bits of the given number.
  """
  def get_bits(0), do: 0
  def get_bits(n) when n >= (1 <<< 128), do: __get_bits(n >>> 128, 128)
  def get_bits(n), do: guess_bits(n, 0, 128, 128)

  defp __get_bits(0, ans), do: ans
  defp __get_bits(n, ans) when n >= (1 <<< 128), do: __get_bits(n >>> 128, 128 + ans)
  defp __get_bits(n, ans), do: __get_bits(0, ans + guess_bits(n, 0, 128, 128))
  
  defp guess_bits(_, l, r, ans) when l > r, do: ans
  defp guess_bits(n, l, r, ans) do
    mid = (l + r) >>> 1;
    if(n >>> mid == 0) do
      guess_bits(n, l, mid - 1, mid)
    else
      guess_bits(n, mid + 1, r, ans)
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

  ## This code block is filled with functions used in the insert! method.
  defp empty_insert!(v, x) do
    %Veb{v | min: x, max: x}
  end

  defp insert_process_one({v, x}) do
    if x < v.min do
      {%Veb{v | min: x}, v.min}
    else
      {v, x}
    end
  end

  defp insert_process_three({v, x}) do
    if x > v.max do
      %Veb{v | max: x}
    else
      v
    end
  end

  defp check_pos(v, pos) do
    case v.cluster[pos] do
      nil -> %Veb{v | cluster: v.cluster |> Map.put_new(pos, %Veb{__struct__() | log_u: v.log_u >>> 1})}
      _ -> v
    end
  end

  defp check_summary(v) do
    case v.summary do
      nil -> %Veb{v | summary: %Veb{log_u: (v.log_u + 1) >>> 1, min: nil, max: nil, summary: nil, cluster: %{}}}
      _ -> v
    end
  end

  defp insert_process_two({v, x}) do
    if v.log_u == 1 do
      {v, x}
    else
      newV = v |> check_pos(high(x, v.log_u)) |> check_summary()
      if min(newV.cluster[high(x, v.log_u)]) == nil do
        {%Veb{newV | summary: insert_unsafe(newV.summary, high(x, v.log_u)), cluster: %{newV.cluster | high(x, v.log_u) => empty_insert!(newV.cluster[high(x, v.log_u)], low(x, v.log_u))}}, x}
      else
        {%Veb{newV | cluster: %{newV.cluster | high(x, v.log_u) => insert_unsafe(newV.cluster[high(x, v.log_u)], low(x, v.log_u))}}, x}
      end
    end
  end

  @spec new(non_neg_integer, :by_max | :by_u | :by_logu) :: t
  @doc """
  Create a tree, using the given $u$, or deriving $u$ from the given max value. The second mode is set as default. You can change the mode by providing the atom.
  """
  def new(limit, mode \\ :by_max) do
    case mode do
      :by_max -> %Veb{__struct__() | log_u: get_bits(limit)}
      :by_u -> %Veb{__struct__() | log_u: get_bits(limit) - 1}
      :by_logu -> %Veb{__struct__() | log_u: limit}
    end
  end

  @spec insert_unsafe(t, non_neg_integer) :: t
  @doc """
  insert! an element unsafely, you should make sure that the element is within the bound.
  """
  def insert_unsafe(v, x) do
    if v. min == nil do
      empty_insert!(v, x)
    else
      {v, x} |> insert_process_one() |> insert_process_two() |> insert_process_three()
    end
  end

  @spec insert!(t, non_neg_integer) :: t
  @doc """
  insert an element with overflow check.
  """
  def insert!(v, x) do
    cond do
      x >= (1 <<< v.log_u) || x < 0 ->
        raise(Veb.InsertError, "invalid key value")
      member?(v, x) ->
        raise(Veb.InsertError, "already inserted")
      true -> insert_unsafe(v, x)
    end
  end

  @spec insert(t, non_neg_integer) :: t | {:error, t}
  @doc """
  insert an element, if existed, do nothing. Or return {:error, v} when the value is not valid.
  """
  def insert(v, x) do
    cond do
      x >= (1 <<< v.log_u) || x < 0 -> {:error, v}
      true -> insert_unsafe(v, x)
    end
  end

  @spec from_list(list, non_neg_integer, :auto | :by_max | :by_u | :by_logu) :: t
  @doc """
  Create a tree from a list. Similarily as the new(), you can change the mode by providing the atom. \":auto\" is set as default, which is to enum the list to find the max value.
  """
  def from_list(list, limit \\ 0, mode \\ :auto) do
    cond do
      mode == :auto || limit <= 0 -> List.foldl(list, new(Enum.max(list), :by_max), fn x, acc -> Veb.insert!(acc, x) end)
      true -> List.foldl(list, new(limit, mode), fn x, acc -> Veb.insert!(acc, x) end)
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
  defp delete_process_one({v, x}) do
    if x == v.min do
      first_cluster = min(v.summary)
      newX = index(first_cluster, min(v.cluster[first_cluster]), v.log_u)
      newV = %Veb{v | min: newX}
      {newV, newX}
    else
      {v, x}
    end
  end

  defp delete_process_two({v, x}) do
    {%Veb{v | cluster: %{v.cluster | high(x, v.log_u) => delete_unsafe(v.cluster[high(x, v.log_u)], low(x, v.log_u))}} ,x}
  end

  defp delete_process_three({v, x}) do
    cond do
      min(v.cluster[high(x, v.log_u)]) == nil -> {v, x} |> delete_sub_process_one() |> delete_sub_process_two()
      x == v.max -> %Veb{v | max: index(high(x, v.log_u), max(v.cluster[high(x, v.log_u)]), v.log_u)}
      true -> v
    end
  end

  defp delete_sub_process_one({v, x}) do
    {%Veb{v | summary: delete_unsafe(v.summary, high(x, v.log_u))}, x}
  end

  defp delete_sub_process_two({v, x}) do
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

  @spec delete!(t | nil, non_neg_integer) :: t | nil
  @doc """
  Delete the given element from the tree, if not exist, raise an error.
  """
  def delete!(v, x) do
    case member?(v, x) do
      true -> delete_unsafe(v, x)
      false ->
        raise(Veb.DeleteError, "key value not exist")
    end
  end

  @spec delete(t | nil, non_neg_integer) :: t | nil | {:error, t}
  @doc """
  Delete the given element from the tree, if not exist, do nothing.
  """
  def delete(v, x) do
    case member?(v, x) do
      true -> delete_unsafe(v, x)
      false -> v
    end
  end
  
  @spec delete_unsafe(t | nil, non_neg_integer) :: t | nil
  @doc """
  Delete the given element from the tree, may cause unexpected result when the key is invalid.
  """
  def delete_unsafe(nil, _x), do: nil
  def delete_unsafe(v, x) do
    cond do
      v.min == v.max && v.min == x -> %Veb{Veb.__struct__ | log_u: v.log_u}
      v.log_u == 1 ->
        if x == 0 do
          %Veb{v | min: 1, max: 1}
        else
          %Veb{v | min: 0, max: 0}
        end
      true ->
        {v, x} |> delete_process_one() |> delete_process_two() |> delete_process_three()
    end
  end

  @spec to_list(t) :: list
  @doc """
  Create a list from a tree. Note that nil tree is not supported and will cause runtime error.
  """
  def to_list(v) do
    __to_list(v, v.max, [])
  end
  defp __to_list(_v, nil, list), do: list
  defp __to_list(v, cur, list), do: __to_list(v, Veb.pred(v, cur), [cur | list])


  defimpl Enumerable do
    def member?(v, num) do
      {:ok, Veb.member?(v, num)}
    end

    def count(_v) do
      {:error, __MODULE__}
    end

    def reduce(v, acc, fun) do
      __reduce({v, v.min}, acc, fun)
    end

    defp __reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
    defp __reduce({v, cur}, {:suspend, acc}, fun), do: {:suspended, acc, &__reduce({v, cur}, &1, fun)}
    defp __reduce({_v, nil}, {:cont, acc}, _fun), do: {:done, acc}
    defp __reduce({v, cur}, {:cont, acc}, fun), do: __reduce({v, Veb.succ(v, cur)}, fun.(cur, acc), fun)

    def slice(v) do
      {:ok, Enum.count(v), &Enum.slice(Veb.to_list(v), &1, &2)}
    end
  end

  defimpl Collectable do
    def into(original) do
      {original, fn
        veb, {:cont, x} -> Veb.insert!(veb, x)
        veb, :done -> veb
        _, :halt -> :ok
      end}
    end
  end

  defimpl Inspect do
    def inspect(v, _opt \\ []) do
      "#Veb<[maxValueLimit: "
      <> Kernel.inspect((1 <<< v.log_u) - 1)
      <> ", data: "
      <> Kernel.inspect(Veb.to_list(v))
      <> "]>"
    end
  end
end


