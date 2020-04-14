defmodule ApiWeb.ShapeView do
  use ApiWeb.Web, :api_view

  alias ApiWeb.{RouteView, StopView}
  alias State.{Route, Stop, StopsOnRoute}

  alias JaSerializer.Relationship.HasMany
  alias JaSerializer.Relationship.HasOne

  location(:shape_location)

  def shape_location(shape, conn), do: shape_path(conn, :show, shape.id)

  attributes([:name, :direction_id, :polyline, :priority])

  @impl true
  def attributes(shape, %{assigns: %{api_version: version}})
      when version >= "2020-05-01" do
    %{
      polyline: shape.polyline
    }
  end

  def attributes(shape, conn) do
    super(shape, conn)
  end

  @impl true
  def relationships(_shape, %{assigns: %{api_version: version}})
      when version >= "2020-05-01" do
    %{}
  end

  def relationships(shape, conn) do
    %{
      route: %HasOne{
        serializer: RouteView,
        data: optional_relationship("routes", shape.route_id, &Route.by_id/1, conn)
      },
      stops: %HasMany{
        serializer: StopView,
        data:
          Enum.map(
            StopsOnRoute.by_route_id(shape.route_id, shape_ids: [shape.id]),
            &Stop.by_id/1
          ),
        identifiers: :always
      }
    }
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
