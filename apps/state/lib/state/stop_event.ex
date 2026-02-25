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
    |> apply_additional_filters(Map.delete(filters, :trip_ids))
  end

  def filter_by(%{stop_ids: stop_ids} = filters) when is_list(stop_ids) and stop_ids != [] do
    stop_ids
    |> by_stop_ids()
    |> apply_additional_filters(Map.delete(filters, :stop_ids))
  end

  def filter_by(%{route_ids: route_ids} = filters) when is_list(route_ids) and route_ids != [] do
    route_ids
    |> by_route_ids()
    |> apply_additional_filters(Map.delete(filters, :route_ids))
  end

  def filter_by(%{vehicle_ids: vehicle_ids} = filters)
      when is_list(vehicle_ids) and vehicle_ids != [] do
    vehicle_ids
    |> by_vehicle_ids()
    |> apply_additional_filters(Map.delete(filters, :vehicle_ids))
  end

  def filter_by(%{direction_id: direction_id}) do
    all()
    |> Enum.filter(fn %StopEvent{direction_id: d_id} -> d_id == direction_id end)
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end

  def filter_by(_filters) do
    []
  end

  defp apply_additional_filters(events, %{trip_ids: trip_ids} = filters)
       when is_list(trip_ids) do
    trip_id_set = MapSet.new(trip_ids)

    Enum.filter(events, fn %StopEvent{trip_id: trip_id} ->
      MapSet.member?(trip_id_set, trip_id)
    end)
    |> apply_additional_filters(Map.delete(filters, :trip_ids))
  end

  defp apply_additional_filters(events, %{stop_ids: stop_ids} = filters)
       when is_list(stop_ids) do
    stop_id_set = MapSet.new(stop_ids)

    Enum.filter(events, fn %StopEvent{stop_id: stop_id} ->
      MapSet.member?(stop_id_set, stop_id)
    end)
    |> apply_additional_filters(Map.delete(filters, :stop_ids))
  end

  defp apply_additional_filters(events, %{route_ids: route_ids} = filters)
       when is_list(route_ids) do
    route_id_set = MapSet.new(route_ids)

    Enum.filter(events, fn %StopEvent{route_id: route_id} ->
      MapSet.member?(route_id_set, route_id)
    end)
    |> apply_additional_filters(Map.delete(filters, :route_ids))
  end

  defp apply_additional_filters(events, %{vehicle_ids: vehicle_ids} = filters)
       when is_list(vehicle_ids) do
    vehicle_id_set = MapSet.new(vehicle_ids)

    Enum.filter(events, fn %StopEvent{vehicle_id: vehicle_id} ->
      MapSet.member?(vehicle_id_set, vehicle_id)
    end)
    |> apply_additional_filters(Map.delete(filters, :vehicle_ids))
  end

  defp apply_additional_filters(events, %{direction_id: direction_id} = filters) do
    Enum.filter(events, fn %StopEvent{direction_id: d_id} ->
      d_id == direction_id
    end)
    |> apply_additional_filters(Map.delete(filters, :direction_id))
  end

  defp apply_additional_filters(events, _filters) do
    events
  end
end
