defmodule ApiWeb.ShapeView do
  use ApiWeb.Web, :api_view

  alias ApiWeb.{RouteView, StopView}
  alias State.{Stop, StopsOnRoute}

  location(:shape_location)

  def shape_location(shape, conn), do: shape_path(conn, :show, shape.id)

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

  def name(%{name: name}, %{assigns: %{api_version: version}}) when version >= "2019-07-01" do
    name
  end

  def name(%{name: name}, _conn) do
    case String.split(name, " - ", parts: 2) do
      [_, name] -> name
      [name] -> name
    end
  end
end
