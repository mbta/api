defmodule State.Server.Query do
  @moduledoc """
  Queries a Server given a map of values.

  Given a Server module and a map of key -> [value], return the values from
  the Server where each of the keys has one of the values from the given
  list. A key without a provided list can have any value.

  An example query for schedules would look like:

  %{
     trip_id: ["1", "2"],
     stop_id: ["3", "4"]
  }

  And the results would be the schedules on trip 1 or 2, stopping at stop 3 or 4.
  """

  @type q :: map
  @type recordable :: struct
  @type index :: atom

  alias State.Server

  @spec query(module, q | [q]) :: [recordable] when q: map, recordable: struct
  def query(module, %{} = q) when is_atom(module) do
    do_query(module, q)
  end

  def query(module, [%{} = q]) when is_atom(module) do
    do_query(module, q)
  end

  def query(module, [%{} | _] = qs) do
    Enum.flat_map(qs, &do_query(module, &1))
  end

  def query(_module, []) do
    []
  end

  defp do_query(module, q) when map_size(q) > 0 do
    recordable = module.recordable()

    {is_db_index?, index} = first_index(module.indices(), q)
    {index_values, rest} = Map.pop(q, index)

    struct = recordable.filled(:_)
    acc = {struct, [], [], 1}

    case {is_db_index?, Enum.reduce_while(rest, acc, &build_struct_and_guards/2)} do
      {true, {^struct, [], filter_fns, _}} ->
        results = Server.by_index(index_values, module, {index, module.key_index()}, [])
        filter_results(results, filter_fns)

      {true, {struct, [], filter_fns, _}} ->
        records = records_from_struct_and_values(struct, index, index_values)
        results = :lists.flatmap(&Server.by_index_match(&1, module, index, []), records)
        filter_results(results, filter_fns)

      {_, {struct, guards, filter_fns, _}} ->
        selectors =
          for record <- records_from_struct_and_values(struct, index, index_values) do
            {
              record,
              guards,
              [:"$_"]
            }
          end

        results = Server.select_with_selectors(module, selectors)
        filter_results(results, filter_fns)

      {_, :empty} ->
        []
    end
  end

  defp do_query(_, _) do
    []
  end

  defp filter_results(results, [head | tail]) do
    case :lists.filter(head, results) do
      [_ | _] = results ->
        filter_results(results, tail)

      [] ->
        []
    end
  end

  defp filter_results(results, []) do
    results
  end

  defp records_from_struct_and_values(%{__struct__: recordable} = struct, index, index_values) do
    for value <- index_values do
      struct
      |> Map.put(index, value)
      |> recordable.to_record()
    end
  end

  @doc """
  Returns the first index which has a value in the query.

  If no index has a value in the query, return any key that's there.

  ## Examples

      iex> first_index([:a, :b], %{a: 1})
      {true, :a}
      iex> first_index([:a, :b], %{a: 1, b: 2})
      {true, :a}

      iex> first_index([:a, :b], %{b: 2})
      {true, :b}

      iex> first_index([:a, :b], %{c: 3})
      {false, :c}
  """
  @spec first_index([index, ...], q) :: {boolean, index}
  def first_index(indices, q) do
    index = Enum.find(indices, &Map.has_key?(q, &1))

    if index do
      {true, index}
    else
      {false, List.first(Map.keys(q))}
    end
  end

  defp build_struct_and_guards({key, [value]}, {struct, guards, filter_fns, i}) do
    struct = Map.put(struct, key, value)
    {:cont, {struct, guards, filter_fns, i}}
  end

  defp build_struct_and_guards(
         {key, [_ | _] = values},
         {struct, guards, filter_fns, i}
       ) do
    set = MapSet.new(values)
    set_filter_fn = fn %{^key => value} -> MapSet.member?(set, value) end
    filter_fns = [set_filter_fn | filter_fns]

    {:cont, {struct, guards, filter_fns, i}}
  end

  defp build_struct_and_guards({_key, []}, _) do
    {:halt, :empty}
  end
end
