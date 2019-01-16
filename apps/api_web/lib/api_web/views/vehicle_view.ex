defmodule ApiWeb.VehicleView do
  use ApiWeb.Web, :api_view

  location("/vehicles/:id")

  attributes([
    :direction_id,
    :label,
    :latitude,
    :longitude,
    :bearing,
    :speed,
    :current_status,
    :current_stop_sequence,
    :updated_at
  ])

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

  def attributes(vehicle, conn) do
    vehicle
    |> super(conn)
    |> backwards_compatible_attributes(vehicle, conn.assigns.api_version)
  end

  for status <- ~w(in_transit_to incoming_at stopped_at)a do
    status_binary =
      status
      |> Atom.to_string()
      |> String.upcase()

    def current_status(%{current_status: unquote(status)}, _conn) do
      unquote(status_binary)
    end
  end

  def current_status(_, _) do
    nil
  end

  defp backwards_compatible_attributes(attributes, vehicle, "2017-11-28") do
    Map.put(attributes, :last_updated, vehicle.updated_at)
  end

  defp backwards_compatible_attributes(attributes, _, _) do
    attributes
  end
end
