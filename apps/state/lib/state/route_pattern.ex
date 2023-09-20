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
          optional(:ids) => [RoutePattern.id()],
          optional(:canonical) => boolean(),
          optional(:route_ids) => [Route.id()],
          optional(:stop_ids) => [Stop.id()]
        }

  @impl State.Server
  def post_load_hook(route_patterns) do
    Enum.sort_by(route_patterns, & &1.sort_order)
  end

  @spec by_id(String.t()) :: RoutePattern.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [route_pattern] -> route_pattern
    end
  end

  @spec filter_by(filters()) :: [RoutePattern.t()]
  def filter_by(%{ids: ids}) do
    by_ids(ids)
  end

  def filter_by(%{canonical: canonical} = filters) do
    filters
    |> Map.delete(:canonical)
    |> filter_by()
    |> Enum.filter(fn %RoutePattern{canonical: is_c} -> canonical == is_c end)
  end

  def filter_by(%{route_ids: _route_ids, stop_ids: _stop_ids} = filters) do
    ids_from_stops = ids_from_stops(filters)
    ids_from_routes = ids_from_routes(filters)
    ids = ids_from_routes -- ids_from_routes -- ids_from_stops
    by_ids(ids)
  end

  def filter_by(%{route_ids: _route_ids} = filters) do
    filters
    |> ids_from_routes()
    |> by_ids()
  end

  def filter_by(%{stop_ids: _stop_ids} = filters) do
    filters
    |> ids_from_stops
    |> by_ids()
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end

  defp ids_from_stops(%{stop_ids: stop_ids} = filters) do
    opts =
      case filters do
        %{direction_id: direction_id} -> [direction_id: direction_id]
        _ -> []
      end

    RoutesPatternsAtStop.route_patterns_by_family_stops(stop_ids, opts)
  end

  defp ids_from_routes(%{route_ids: route_ids} = filters) do
    opts =
      case filters do
        %{direction_id: direction_id} -> %{routes: route_ids, direction_id: direction_id}
        _ -> %{routes: route_ids}
      end

    opts
    |> Trip.filter_by()
    |> Enum.map(& &1.route_pattern_id)
    |> Enum.uniq()
  end
end
