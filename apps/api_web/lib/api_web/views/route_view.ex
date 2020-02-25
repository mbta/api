defmodule ApiWeb.RouteView do
  use ApiWeb.Web, :api_view

  location(:route_location)

  def route_location(route, conn), do: route_path(conn, :show, route.id)

  has_one(
    :line,
    type: :line,
    serializer: ApiWeb.LineView
  )

  has_many(
    :route_patterns,
    type: :route_pattern,
    serializer: ApiWeb.RoutePatternView
  )

  # no cover
  attributes([
    :description,
    :fare_class,
    :short_name,
    :long_name,
    :sort_order,
    :type,
    :color,
    :text_color,
    :direction_names,
    :direction_destinations
  ])

  def attributes(route, _conn) do
    # need to override so that the default type/2 method (which returns
    # "route") doesn't replace the "type" attribute of %Route{}
    route
    |> Map.take(~w(
          description
          fare_class
          short_name
          long_name
          sort_order
          type
          color
          text_color
          direction_names
          direction_destinations)a)
  end

  def line(%{line_id: line_id}, conn) do
    optional_relationship("line", line_id, &State.Line.by_id/1, conn)
  end

  def route_patterns(%{id: route_id}, _conn) do
    State.RoutePattern.by_route_id(route_id)
  end

  # Override attribute version of type to give the resource type
  def type(_, _), do: "route"

  def relationships(route, %Plug.Conn{private: %{phoenix_view: __MODULE__}} = conn) do
    # only do this include if we're the top-level view, not if we're included
    # elsewhere
    relationships = super(route, conn)

    if split_included?("stop", conn) do
      stop_id =
        case conn.params do
          %{"filter" => %{"stop" => stop_id}} ->
            stop_id

          %{"stop" => stop_id} ->
            stop_id

          _ ->
            nil
        end

      stop = State.Stop.by_id(stop_id)

      put_in(relationships[:stop], %HasOne{
        type: :stop,
        name: :stop,
        data: stop,
        include: nil,
        identifiers: :always,
        serializer: ApiWeb.StopView
      })
    else
      relationships
    end
  end

  def relationships(route, conn) do
    super(route, conn)
  end
end
