defmodule State.Alert.Hooks do
  @moduledoc """
  Implementation of hooks to process Alerts before inserting them into the table.
  """
  alias Model.Alert

  @spec pre_insert_hook(Alert.t()) :: [Alert.t()]
  def pre_insert_hook(alert) do
    [%{alert | informed_entity: add_computed_entities(alert.informed_entity)}]
  end

  defp add_computed_entities(entities) do
    entities
    |> Stream.concat(get_parent_station_entities(entities))
    |> Enum.flat_map(&include_alternate_trip_entities/1)
    |> Enum.uniq()
  end

  # Parent station informed entities that share values for these keys
  # will each have their `activities` replaced with the union of all of
  # the group's `activities` lists:
  # [%{activities: ["BOARD"]}, %{activities: ["BOARD", "EXIT"]}]
  # =>
  # [%{activities: ["BOARD", "EXIT"]}, %{activities: ["BOARD", "EXIT"]}]
  @parent_station_entity_activity_merge_criteria [:route, :stop, :trip]

  @spec get_parent_station_entities([Alert.informed_entity()]) :: [Alert.informed_entity()]
  defp get_parent_station_entities(entities) do
    entities
    |> map_child_stop_to_parent_station()
    |> Enum.group_by(&Map.take(&1, @parent_station_entity_activity_merge_criteria))
    |> Enum.flat_map(&merge_parent_entity_activities/1)
  end

  # For each entity in the list:
  # - If it informs a stop that has a parent station, its `:stop` field is replaced with the parent station ID.
  # - Otherwise, it is filtered out of the list.
  @spec map_child_stop_to_parent_station([Alert.informed_entity()]) :: [Alert.informed_entity()]
  defp map_child_stop_to_parent_station(entities) do
    stops = State.Stop.by_ids(for(%{stop: stop_id} <- entities, is_binary(stop_id), do: stop_id))

    stop_to_station =
      for %{id: stop, parent_station: station} <- stops, is_binary(station), into: %{} do
        {stop, station}
      end

    for %{stop: stop} = entity <- entities, (station = stop_to_station[stop]) != nil do
      %{entity | stop: station}
    end
  end

  defp merge_parent_entity_activities({_key, parent_entities}) do
    merged_activities =
      parent_entities
      |> Enum.flat_map(&(&1[:activities] || []))
      |> Enum.uniq()
      |> Enum.sort()

    if merged_activities == [] do
      parent_entities
    else
      parent_entities
      |> Enum.map(&Map.put(&1, :activities, merged_activities))
      |> Enum.uniq()
    end
  end

  @spec include_alternate_trip_entities(Alert.informed_entity()) :: [Alert.informed_entity()]
  defp include_alternate_trip_entities(%{trip: trip_id} = entity) when is_binary(trip_id) do
    case all_route_entities(entity) do
      [] ->
        [entity]

      entities ->
        entities
    end
  end

  defp include_alternate_trip_entities(entity) do
    [entity]
  end

  defp all_route_entities(%{trip: trip_id} = entity) when is_binary(trip_id) do
    trips = State.Trip.by_id(trip_id)

    trip_entities =
      for trip <- trips do
        merge =
          case State.Route.by_id(trip.route_id) do
            nil ->
              %{route: trip.route_id, direction_id: trip.direction_id}

            route ->
              %{
                route: route.id,
                route_type: route.type,
                direction_id: trip.direction_id
              }
          end

        Map.merge(entity, merge)
      end

    with {:ok, route_id} <- Map.fetch(entity, :route),
         false <- Enum.any?(trips, &(&1.route_id == route_id)) do
      # if the route in the alert doesn't match the routes we have for the
      # trip, keep the original entity
      [entity | trip_entities]
    else
      _ ->
        # otherwise, ignore the original entity
        trip_entities
    end
  end
end
