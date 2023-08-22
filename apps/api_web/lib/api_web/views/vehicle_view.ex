defmodule ApiWeb.VehicleView do
  use ApiWeb.Web, :api_view

  location(:vehicle_location)

  def vehicle_location(vehicle, conn), do: vehicle_path(conn, :show, vehicle.id)

  attributes([
    :direction_id,
    :label,
    :latitude,
    :longitude,
    :bearing,
    :speed,
    :current_status,
    :current_stop_sequence,
    :updated_at,
    :occupancy_status,
    :carriages
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
    |> encode_carriages()
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

  for status <-
        ~w(empty many_seats_available few_seats_available standing_room_only crushed_standing_room_only full not_accepting_passengers)a do
    status_binary =
      status
      |> Atom.to_string()
      |> String.upcase()

    def occupancy_status(%{occupancy_status: unquote(status)}, _conn) do
      unquote(status_binary)
    end
  end

  def occupancy_status(_, _) do
    nil
  end

  defp backwards_compatible_attributes(attributes, vehicle, "2017-11-28") do
    Map.put(attributes, :last_updated, vehicle.updated_at)
  end

  defp backwards_compatible_attributes(attributes, _, _) do
    attributes
  end

  defp encode_carriages(vehicle) do
    Map.put(vehicle, :carriages, vehicle.carriages |> Enum.map(&encode_carriage/1))
  end

  defp encode_carriage(carraige) do
    %{
      label: carraige.label,
      carriage_sequence: carraige.carriage_sequence,
      occupancy_status: carraige.occupancy_status,
      occupancy_percentage: carraige.occupancy_percentage
    }
  end
end
