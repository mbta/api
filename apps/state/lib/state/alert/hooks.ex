defmodule State.Alert.Hooks do
  @moduledoc """
  Implementation of hooks to process Alerts before inserting them into the table.
  """
  alias Model.Alert

  @spec pre_insert_hook(Alert.t()) :: [Alert.t()]
  def pre_insert_hook(alert) do
    entities = entities_with_parents(alert.informed_entity)

    [
      %{alert | informed_entity: entities}
    ]
  end

  defp entities_with_parents(entities) do
    entities
    |> Stream.flat_map(&include_entity_parent_stop/1)
    |> Stream.flat_map(&include_entity_alternate_trips/1)
    |> Enum.group_by(&get_key/1)
    |> Stream.map(&merge_entities/1)
    |> Enum.uniq()
  end

  defp get_key(%{} = ie), do: Map.take(ie, ~w(route stop trip)a)

  defp merge_entities({%{} = key, entities}) do
    merged =
      [:route, :stop, :trip]
      |> Enum.reduce(Map.new(), &put_optional_key(&2, key, &1))
      |> put_optional_activies(entities)

    [:direction_id, :facility, :route_type]
    |> Enum.reduce(merged, &put_optional_value(&2, entities, &1))
  end

  defp put_optional_key(%{} = merged, %{} = key, inner_key) when is_atom(inner_key) do
    case Map.get(key, inner_key) do
      k when is_binary(k) -> Map.put(merged, inner_key, k)
      nil -> merged
    end
  end

  defp put_optional_value(%{} = merged, [head | _], value_name) when is_atom(value_name) do
    case Map.get(head, value_name) do
      nil -> merged
      v -> Map.put(merged, value_name, v)
    end
  end

  defp put_optional_activies(%{} = merged, [_ | _] = entities) do
    activities =
      Enum.reduce(entities, MapSet.new(), fn ie, acc ->
        case Map.get(ie, :activities) do
          [_ | _] = activities -> MapSet.union(acc, MapSet.new(activities))
          _ -> acc
        end
      end)

    case MapSet.size(activities) do
      0 -> merged
      _ -> Map.put(merged, :activities, MapSet.to_list(activities))
    end
  end

  defp put_optional_activies(%{} = merged, _), do: merged

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

  defp include_entity_alternate_trips(%{trip: trip_id} = entity) when is_binary(trip_id) do
    case all_route_entities(entity) do
      [] ->
        [entity]

      entities ->
        entities
    end
  end

  defp include_entity_alternate_trips(entity) do
    [entity]
  end

  defp include_entity_parent_stop(%{stop: stop_id} = entity) when is_binary(stop_id) do
    case State.Stop.by_id(stop_id) do
      %{parent_station: station} when is_binary(station) ->
        [entity, %{entity | stop: station}]

      _ ->
        [entity]
    end
  end

  defp include_entity_parent_stop(entity) do
    [entity]
  end
end
