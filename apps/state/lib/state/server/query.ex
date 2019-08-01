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

  @spec query(module, q) :: [recordable] when q: map, recordable: struct
  def query(module, %{} = q) when is_atom(module) do
    do_query(module, q)
  end

  defp do_query(module, q) when map_size(q) > 0 do
    index = first_index(module.indices(), q)
    index_values = Map.get(q, index)
    rest = Map.delete(q, index)

    {struct, guards} =
      rest
      |> Enum.with_index(1)
      |> Enum.reduce({module.recordable().filled(:_), []}, &build_struct_and_guards/2)

    match_specs =
      for value <- index_values do
        record =
          struct
          |> Map.put(index, value)
          |> module.recordable().to_record()

        {record, guards, [:"$_"]}
      end

    Server.select_with_selectors(module, match_specs)
  end

  defp do_query(_module, _q) do
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

      iex> build_guard(:x, [1])
      {:==, :x, 1}

      iex> build_guard(:y, [1, 2])
      {:orelse, {:==, :y, 1}, {:==, :y, 2}}

      iex> build_guard(:z, [])
      false
  """
  @spec build_guard(variable, values) :: tuple when variable: atom, values: [any]
  def build_guard(variable, values)

  def build_guard(variable, [_, _ | _] = values) do
    guards = for value <- values, do: build_guard(variable, [value])
    List.to_tuple([:orelse | guards])
  end

  def build_guard(variable, [value]) do
    {:==, variable, value}
  end

  def build_guard(_variable, []) do
    false
  end

  defp build_struct_and_guards({{key, values}, i}, {struct, guards}) do
    query_variable = String.to_atom("$#{i}")
    struct = Map.put(struct, key, query_variable)
    guard = build_guard(query_variable, values)
    {struct, [guard | guards]}
  end
end
