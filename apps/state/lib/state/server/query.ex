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

  @spec query(module, q | [q, ...]) :: [recordable] when q: map, recordable: struct
  def query(module, %{} = q) when is_atom(module) do
    do_query(module, [q])
  end

  def query(module, [%{} | _] = qs) do
    do_query(module, qs)
  end

  defp do_query(module, qs) do
    selectors = Enum.flat_map(qs, &do_build_selectors(module, &1))

    if selectors == [] do
      []
    else
      Server.select_with_selectors(module, selectors)
    end
  end

  defp do_build_selectors(module, q) when map_size(q) > 0 do
    index = first_index(module.indices(), q)
    rest = Map.delete(q, index)
    recordable = module.recordable()

    case Enum.reduce_while(rest, {recordable.filled(:_), [], 1}, &build_struct_and_guards/2) do
      {struct, guards, _} ->
        # put shorter guards at the front
        guards = Enum.sort(guards)

        index_values = Map.get(q, index)

        match_specs =
          for value <- index_values do
            record =
              struct
              |> Map.put(index, value)
              |> recordable.to_record()

            {record, guards, [:"$_"]}
          end

        match_specs

      :empty ->
        []
    end
  end

  defp do_build_selectors(_module, _q) do
    []
  end

  @doc """
  Returns the first index which has a value in the query.

  If no index has a value in the query, return any key that's there.

  ## Examples

      iex> first_index([:a, :b], %{a: 1})
      :a
      iex> first_index([:a, :b], %{a: 1, b: 2})
      :a

      iex> first_index([:a, :b], %{b: 2})
      :b

      iex> first_index([:a, :b], %{c: 3})
      :c
  """
  @spec first_index([index, ...], q) :: index
  def first_index(indices, q) do
    index = Enum.find(indices, &Map.has_key?(q, &1))

    if index do
      index
    else
      List.first(Map.keys(q))
    end
  end

  @doc """
  Generate a guard for a match specification where the variable is one of the provided values.

  ## Examples
      iex> build_guard(:y, [1, 2])
      {:orelse, {:"=:=", :y, 1}, {:"=:=", :y, 2}}
  """
  @spec build_guard(variable, values) :: tuple when variable: atom, values: [any, ...]
  def build_guard(variable, [_, _ | _] = values) do
    guards = for value <- values, do: {:"=:=", variable, value}
    List.to_tuple([:orelse | guards])
  end

  defp build_struct_and_guards({key, [value]}, {struct, guards, i}) do
    struct = Map.put(struct, key, value)
    {:cont, {struct, guards, i}}
  end

  defp build_struct_and_guards({key, [_, _ | _] = values}, {struct, guards, i}) do
    query_variable = query_variable(i)
    struct = Map.put(struct, key, query_variable)
    guard = build_guard(query_variable, values)
    {:cont, {struct, [guard | guards], i + 1}}
  end

  defp build_struct_and_guards({_key, []}, _) do
    {:halt, :empty}
  end

  # build query variables at compile time
  for i <- 1..20 do
    defp query_variable(unquote(i)), do: unquote(String.to_atom("$#{i}"))
  end
end
