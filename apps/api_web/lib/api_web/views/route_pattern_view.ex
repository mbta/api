defmodule ApiWeb.RoutePatternView do
  use ApiWeb.Web, :api_view

  location("/route-patterns/:id")

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
    :sort_order
  ])

  defp fetch_representative_trip(trip_id) do
    case State.Trip.by_id(trip_id) do
      [] -> nil
      [trip] -> trip
    end
  end

  def representative_trip(%{representative_trip_id: trip_id}, conn) do
    optional_relationship("representative_trip", trip_id, &fetch_representative_trip/1, conn)
  end
end
