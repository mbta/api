defmodule State.Vehicle do
  @moduledoc """
  Maintains the list of currently active vehicles.  Queryable by:
  * vehicle ID
  * trip ID
  * route ID
  * label
  """
  use State.Server,
    indicies: [:id, :trip_id, :effective_route_id, :label],
    parser: Parse.VehiclePositions,
    recordable: Model.Vehicle

  alias Model.Vehicle
  alias State.Trip

  @type direction_id :: Model.Trip.id() | nil
  @type routes :: [Model.Route.id()]
  @type labels :: [Vehicle.label()]

  @impl State.Server
  def post_load_hook(structs) do
    Enum.uniq_by(structs, & &1.trip_id)
  end

  @spec by_id(Vehicle.id()) :: Vehicle.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [vehicle] -> vehicle
    end
  end

  @impl State.Server
  def pre_insert_hook(vehicle) do
    update_effective_route_id(vehicle)
  end

  defp update_effective_route_id(%Vehicle{trip_id: trip_id} = vehicle) do
    case Trip.by_id(trip_id) do
      [] ->
        # make sure the effective_route_id is assigned since that's what we
        # query for
        [%{vehicle | effective_route_id: vehicle.route_id}]

      trips ->
        for trip <- trips do
          %{vehicle | effective_route_id: trip.route_id}
        end
    end
  end

  @spec by_trip_ids([Vehicle.id()]) :: [Vehicle.t()]
  def by_trip_ids(trip_ids) do
    trip_ids
    |> build_trip_matchers()
    |> select(:trip_id)
  end

  defp build_trip_matchers(trip_ids) do
    for trip_id <- trip_ids do
      %{trip_id: trip_id}
    end
  end

  @spec by_labels(labels) :: [Vehicle.t()]
  def by_labels(labels) do
    labels
    |> build_label_matchers()
    |> select(:label)
  end

  defp build_label_matchers(labels) do
    for label <- labels do
      %{label: label}
    end
  end

  @spec by_labels_and_routes(labels, routes, direction_id) :: [Vehicle.t()]
  def by_labels_and_routes(labels, route_ids, direction_id) do
    labels
    |> build_label_and_route_matchers(route_ids, direction_id)
    |> select(:label)
  end

  defp build_label_and_route_matchers(labels, route_ids, nil) do
    for label <- labels, route_id <- route_ids do
      %{label: label, effective_route_id: route_id}
    end
  end

  defp build_label_and_route_matchers(labels, route_ids, direction_id) do
    for label <- labels, route_id <- route_ids do
      %{label: label, effective_route_id: route_id, direction_id: direction_id}
    end
  end

  @spec by_route_ids_and_direction_id(routes, direction_id) :: [Vehicle.t()]
  def by_route_ids_and_direction_id(route_ids, direction_id) do
    route_ids
    |> build_route_and_direction_matchers(direction_id)
    |> select(:effective_route_id)
  end

  defp build_route_and_direction_matchers(route_ids, nil) do
    for route_id <- route_ids do
      %{effective_route_id: route_id}
    end
  end

  defp build_route_and_direction_matchers(route_ids, direction_id) do
    for route_id <- route_ids do
      %{effective_route_id: route_id, direction_id: direction_id}
    end
  end
end
