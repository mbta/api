defmodule ApiWeb.RoutePatternView do
  use ApiWeb.Web, :api_view

  location(:route_pattern_location)

  def route_pattern_location(route_pattern, conn),
    do: route_pattern_path(conn, :show, route_pattern.id)

  has_one(
    :route,
    type: :route,
    serializer: ApiWeb.RouteView
  )

  has_one(
    :representative_trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    field: :representative_trip_id
  )

  # no cover
  attributes([
    :direction_id,
    :name,
    :time_desc,
    :typicality,
    :sort_order,
    :is_canonical
  ])

  def representative_trip(%{representative_trip_id: trip_id}, conn) do
    optional_relationship("representative_trip", trip_id, &State.Trip.by_primary_id/1, conn)
  end

  def is_canonical(%{is_canonical: 1}, _), do: true
  def is_canonical(%{is_canonical: 2}, _), do: false
  def is_canonical(%{is_canonical: _}, _), do: nil
end
