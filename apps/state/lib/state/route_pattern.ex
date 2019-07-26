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

  @type filters :: %{
          optional(:ids) => [RoutePattern.id()],
          optional(:route_ids) => [Route.id()],
          optional(:stop_ids) => [Stop.id()]
        }

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

  def filter_by(%{route_ids: route_ids, stop_ids: stop_ids} = filters) do
    opts =
      case filters do
        %{direction_id: direction_id} -> [direction_id: direction_id]
        _ -> []
      end

    ids = RoutesPatternsAtStop.route_patterns_by_stops_and_direction(stop_ids, opts)

    matchers =
      for id <- ids, route_id <- route_ids do
        %{route_id: route_id, id: id}
      end

    select(matchers, :id)
  end

  def filter_by(%{route_ids: route_ids, direction_id: direction_id}) do
    matchers = for route_id <- route_ids, do: %{route_id: route_id, direction_id: direction_id}
    select(matchers, :route_id)
  end

  def filter_by(%{route_ids: route_ids}) do
    by_route_ids(route_ids)
  end

  def filter_by(%{stop_ids: stop_ids} = filters) do
    opts =
      case filters do
        %{direction_id: direction_id} -> [direction_id: direction_id]
        _ -> []
      end

    stop_ids
    |> RoutesPatternsAtStop.route_patterns_by_stops_and_direction(opts)
    |> by_ids
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end
end
