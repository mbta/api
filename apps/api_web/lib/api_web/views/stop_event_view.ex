defmodule ApiWeb.StopEventView do
  use ApiWeb.Web, :api_view

  location(:stop_event_location)

  def stop_event_location(stop_event, conn),
    do: stop_event_path(conn, :show, stop_event.id)

  has_one(
    :trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    field: :trip_id
  )

  has_one(
    :stop,
    type: :stop,
    serializer: ApiWeb.StopView,
    field: :stop_id
  )

  has_one(
    :route,
    type: :route,
    serializer: ApiWeb.RouteView,
    field: :route_id
  )

  has_one(
    :vehicle,
    type: :vehicle,
    serializer: ApiWeb.VehicleView,
    field: :vehicle_id
  )

  attributes([
    :vehicle_id,
    :start_date,
    :trip_id,
    :direction_id,
    :route_id,
    :start_time,
    :revenue,
    :stop_id,
    :current_stop_sequence,
    :arrived,
    :departed
  ])

  def trip(%{trip_id: trip_id}, conn) do
    optional_relationship("trip", trip_id, &State.Trip.by_primary_id/1, conn)
  end

  def stop(%{stop_id: stop_id}, conn) do
    optional_relationship("stop", stop_id, &State.Stop.by_id/1, conn)
  end

  def route(%{route_id: route_id}, conn) do
    optional_relationship("route", route_id, &State.Route.by_id/1, conn)
  end

  def vehicle(%{vehicle_id: vehicle_id}, conn) do
    optional_relationship("vehicle", vehicle_id, &State.Vehicle.by_id/1, conn)
  end
end
