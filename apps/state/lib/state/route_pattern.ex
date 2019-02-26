defmodule State.RoutePattern do
  @moduledoc """
  State for route patterns
  """
  use State.Server,
    fetched_filename: "route_patterns.txt",
    recordable: Model.RoutePattern,
    indicies: [:id, :route_id],
    parser: Parse.RoutePatterns

  alias Model.Route
  alias Model.RoutePattern

  @type filters :: %{
          optional(:ids) => [RoutePattern.id()],
          optional(:route_ids) => [Route.id()]
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

  def filter_by(%{route_ids: route_ids}) do
    by_route_ids(route_ids)
  end

  def filter_by(%{} = map) when map_size(map) == 0 do
    all()
  end
end
