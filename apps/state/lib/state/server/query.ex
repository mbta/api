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

  defp do_query(module, q) when map_size(q) == 1 do
    [{index, values}] = Map.to_list(q)
    Server.by_index(values, module, {index, module.key_index}, [])
  end

  defp do_query(module, _q) do
    module.all()
  end
end
