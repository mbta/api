defmodule State.Alert.InformedEntity do
  @moduledoc """
  A flattened cache of the current alerts, for easier querying of informed entities
  """
  use Recordable, [:id, :route_type, :route, :stop, :direction_id, :trip, :facility]
  alias Model.Alert

  @table __MODULE__

  def new(table \\ @table) do
    ^table = :ets.new(table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    :ok
  end

  def match(table \\ @table, matchers) do
    selectors =
      for base_matcher <- matchers,
          matcher <- all_parts(base_matcher) do
        {to_record(matcher), [], [:"$1"]}
      end

    Enum.uniq(:ets.select(table, selectors))
  end

  def update(table \\ @table, items) do
    flattened = Enum.flat_map(items, &flatten/1)

    true = :ets.delete_all_objects(table)
    true = :ets.insert(table, flattened)

    :ok
  end

  defp flatten(%Alert{id: id, informed_entity: entities}) do
    for entity <- entities do
      to_record(%__MODULE__{
        id: id,
        route_type: Map.get(entity, :route_type),
        route: Map.get(entity, :route),
        stop: Map.get(entity, :stop),
        direction_id: Map.get(entity, :direction_id),
        trip: Map.get(entity, :trip),
        facility: Map.get(entity, :facility)
      })
    end
  end

  defp all_parts(matcher) do
    for route_type <- part_values(matcher, :route_type),
        route <- part_values(matcher, :route),
        stop <- part_values(matcher, :stop),
        direction_id <- part_values(matcher, :direction_id),
        trip <- part_values(matcher, :trip),
        facility <- part_values(matcher, :facility) do
      %__MODULE__{
        id: :"$1",
        route_type: route_type,
        route: route,
        stop: stop,
        direction_id: direction_id,
        trip: trip,
        facility: facility
      }
    end
    |> reject_empty_parts
  end

  defp part_values(map, key) do
    case Map.fetch(map, key) do
      {:ok, nil} -> [nil]
      {:ok, value} -> [value, nil]
      :error -> [:_]
    end
  end

  defp reject_empty_parts([part]) do
    # if it's a single part, let it through
    [part]
  end

  defp reject_empty_parts(parts) do
    Enum.filter(parts, &non_empty_part?/1)
  end

  defp non_empty_part?(map) do
    # empty parts are all nil or :_ do
    map
    |> Map.drop([:__struct__, :id])
    |> Map.values()
    |> Enum.any?(&(&1 not in [nil, :_]))
  end
end
