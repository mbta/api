defmodule State.RoutePattern do
  @moduledoc """
  State for route patterns
  """
  use State.Server,
    fetched_filename: "route_patterns.txt",
    recordable: Model.RoutePattern,
    indices: [:id, :route_id],
    parser: Parse.RoutePatterns

  alias Model.Route
  alias Model.RoutePattern
  alias Model.Stop
  alias State.RoutesPatternsAtStop
  alias State.Trip

  @type filters :: %{
          optional(:id) => [RoutePattern.id()],
          optional(:route_id) => [Route.id()],
          optional(:stop_id) => [Stop.id()],
          optional(:direction_id) => [Model.Direction.id()]
        }

  @spec by_id(String.t()) :: RoutePattern.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [route_pattern] -> route_pattern
    end
  end

  @spec filter_by(filters()) :: [RoutePattern.t()]
  def filter_by(%{id: id}) do
    by_ids(id)
  end

  def filter_by(%{route_id: _route_id, stop_id: _stop_id} = filters) do
    ids_from_stops = ids_from_stops(filters)
    ids_from_routes = ids_from_routes(filters)
    id = ids_from_routes -- ids_from_routes -- ids_from_stops
    by_ids(id)
  end

  def filter_by(%{route_id: _route_id} = filters) do
    filters
    |> ids_from_routes()
    |> by_ids()
  end

  def filter_by(%{stop_id: _stop_id} = filters) do
    filters
    |> ids_from_stops
    |> by_ids()
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end

  defp ids_from_stops(%{stop_id: stop_id} = filters) do
    opts =
      case filters do
        %{direction_id: direction_id} -> [direction_id: direction_id]
        _ -> []
      end

    RoutesPatternsAtStop.route_patterns_by_stops_and_direction(stop_id, opts)
  end

  defp ids_from_routes(%{route_id: _} = filters) do
    filters
    |> Map.take([:route_id, :direction_id])
    |> Trip.filter_by()
    |> Enum.map(& &1.route_pattern_id)
    |> Enum.uniq()
  end
end
