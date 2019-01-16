defmodule ApiWeb.ShapeView do
  use ApiWeb.Web, :api_view

  alias ApiWeb.{RouteView, StopView}
  alias State.{Stop, StopsOnRoute}

  location("/shapes/:id")

  attributes([:name, :direction_id, :polyline, :priority])

  has_one(
    :route,
    type: :route,
    serializer: RouteView
  )

  has_many(
    :stops,
    type: :stop,
    identifiers: :always,
    serializer: StopView
  )

  def stops(%{id: id, route_id: route_id}, _conn) do
    route_id
    |> StopsOnRoute.by_route_id(shape_ids: [id])
    |> Stop.by_ids()
  end
end
