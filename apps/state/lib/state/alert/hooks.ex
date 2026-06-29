defmodule State.Alert.Hooks do
  @moduledoc """
  Implementation of hooks to process Alerts before inserting them into the table.
  """
  alias Model.Alert

  @spec pre_insert_hook(Alert.t()) :: [Alert.t()]
  def pre_insert_hook(alert) do
    entities = add_computed_entities(alert.informed_entity)

    [
      %{alert | informed_entity: entities}
    ]
  end

  defp add_computed_entities(entities) do
    entities
    |> Enum.flat_map(&include_alternate_trip_entities/1)
    |> Enum.uniq()
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
