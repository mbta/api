defmodule State.StopEvent do
  @moduledoc """
  State for stop events - actual arrival/departure times of vehicles at stops
  """
  use State.Server,
    indices: [:id, :trip_id, :stop_id, :route_id, :vehicle_id],
    parser: Parse.StopEvents,
    recordable: Model.StopEvent

  alias Model.Route
  alias Model.StopEvent
  alias Model.Stop
  alias Model.Trip

  @type filters :: %{
          optional(:trip_ids) => [Trip.id()],
          optional(:stop_ids) => [Stop.id()],
          optional(:route_ids) => [Route.id()],
          optional(:vehicle_ids) => [String.t()],
          optional(:direction_id) => 0 | 1
        }

  @spec by_id(String.t()) :: StopEvent.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [stop_event] -> stop_event
    end
  end

  @spec filter_by(filters()) :: [StopEvent.t()]
  def filter_by(%{trip_ids: trip_ids} = filters) when is_list(trip_ids) and trip_ids != [] do
    trip_ids
    |> by_trip_ids()
    |> apply_additional_filters(filters)
  end

  def filter_by(%{stop_ids: stop_ids} = filters) when is_list(stop_ids) and stop_ids != [] do
    stop_ids
    |> by_stop_ids()
    |> apply_additional_filters(filters)
  end

  def filter_by(%{route_ids: route_ids} = filters) when is_list(route_ids) and route_ids != [] do
    route_ids
    |> by_route_ids()
    |> apply_additional_filters(filters)
  end

  def filter_by(%{vehicle_ids: vehicle_ids} = filters)
      when is_list(vehicle_ids) and vehicle_ids != [] do
    vehicle_ids
    |> by_vehicle_ids()
    |> apply_additional_filters(filters)
  end

  def filter_by(%{direction_id: _direction_id} = filters) do
    all()
    |> apply_additional_filters(filters)
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end

  def filter_by(_filters) do
    []
  end

  # Pre-compute all MapSets once to avoid repeated creation during filtering
  defp apply_additional_filters(events, filters) do
    # Build all filter sets upfront
    filter_sets = %{
      trip_ids: build_filter_set(filters[:trip_ids]),
      stop_ids: build_filter_set(filters[:stop_ids]),
      route_ids: build_filter_set(filters[:route_ids]),
      vehicle_ids: build_filter_set(filters[:vehicle_ids]),
      direction_id: filters[:direction_id]
    }

    Enum.filter(events, fn event ->
      matches_trip?(event, filter_sets.trip_ids) and
        matches_stop?(event, filter_sets.stop_ids) and
        matches_route?(event, filter_sets.route_ids) and
        matches_vehicle?(event, filter_sets.vehicle_ids) and
        matches_direction?(event, filter_sets.direction_id)
    end)
  end

  defp build_filter_set(nil), do: nil
  defp build_filter_set([]), do: nil
  defp build_filter_set(list) when is_list(list), do: MapSet.new(list)

  defp matches_trip?(_event, nil), do: true
  defp matches_trip?(%StopEvent{trip_id: trip_id}, set), do: MapSet.member?(set, trip_id)

  defp matches_stop?(_event, nil), do: true
  defp matches_stop?(%StopEvent{stop_id: stop_id}, set), do: MapSet.member?(set, stop_id)

  defp matches_route?(_event, nil), do: true
  defp matches_route?(%StopEvent{route_id: route_id}, set), do: MapSet.member?(set, route_id)

  defp matches_vehicle?(_event, nil), do: true

  defp matches_vehicle?(%StopEvent{vehicle_id: vehicle_id}, set),
    do: MapSet.member?(set, vehicle_id)

  defp matches_direction?(_event, nil), do: true
  defp matches_direction?(%StopEvent{direction_id: d_id}, direction_id), do: d_id == direction_id
end
