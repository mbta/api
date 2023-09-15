defmodule Parse.VehiclePositionsJson do
  @moduledoc """

  Parses an enhanced Vehicle Position JSON file into a list of `%Model.Vehicle{}` structs.

  """
  alias Model.Vehicle

  def parse(body) do
    decoded = Jason.decode!(body, strings: :copy)

    entities =
      decoded
      |> Map.get("entity")
      |> Enum.flat_map(&parse_entity/1)

    if decoded["header"]["incrementality"] in ["DIFFERENTIAL", 1] do
      {:partial, entities}
    else
      entities
    end
  end

  def parse_entity(
        %{
          "vehicle" => %{
            "position" => position,
            "trip" => trip,
            "vehicle" => vehicle
          }
        } = entity
      ) do
    data = Map.get(entity, "vehicle")

    [
      %Vehicle{
        id: Map.get(vehicle, "id"),
        trip_id: Map.get(trip, "trip_id"),
        route_id: Map.get(trip, "route_id"),
        direction_id: Map.get(trip, "direction_id"),
        stop_id: Map.get(data, "stop_id"),
        label: Map.get(vehicle, "label"),
        latitude: Map.get(position, "latitude"),
        longitude: Map.get(position, "longitude"),
        bearing: Map.get(position, "bearing"),
        speed: Map.get(position, "speed"),
        current_status: parse_status(Map.get(data, "current_status")),
        current_stop_sequence: Map.get(data, "current_stop_sequence"),
        updated_at: unix_to_local(Map.get(data, "timestamp")),
        consist: parse_consist(Map.get(vehicle, "consist")),
        occupancy_status: parse_occupancy_status(Map.get(data, "occupancy_status")),
        carriages: carriages(Map.get(data, "multi_carriage_details"))
      }
    ]
  end

  def parse_entity(%{}) do
    []
  end

  defp parse_consist([_ | _] = consist) do
    Enum.map(consist, fn %{"label" => car_label} -> car_label end)
  end

  defp parse_consist([]), do: nil
  defp parse_consist(nil), do: nil

  defp parse_status(nil) do
    :in_transit_to
  end

  defp parse_status("IN_TRANSIT_TO") do
    :in_transit_to
  end

  defp parse_status("INCOMING_AT") do
    :incoming_at
  end

  defp parse_status("STOPPED_AT") do
    :stopped_at
  end

  defp carriages(nil), do: []

  defp carriages(multi_carriage_details) do
    for carriage_details <- multi_carriage_details,
        do: %Model.Vehicle.Carriage{
          label: carriage_details["label"],
          carriage_sequence: carriage_details["carriage_sequence"],
          occupancy_status: parse_occupancy_status(carriage_details["occupancy_status"]),
          occupancy_percentage: carriage_details["occupancy_percentage"]
        }
  end

  defp parse_occupancy_status(nil), do: nil

  defp parse_occupancy_status("EMPTY"), do: :empty

  defp parse_occupancy_status("MANY_SEATS_AVAILABLE"), do: :many_seats_available

  defp parse_occupancy_status("FEW_SEATS_AVAILABLE"), do: :few_seats_available

  defp parse_occupancy_status("STANDING_ROOM_ONLY"), do: :standing_room_only

  defp parse_occupancy_status("CRUSHED_STANDING_ROOM_ONLY"), do: :crushed_standing_room_only

  defp parse_occupancy_status("FULL"), do: :full

  defp parse_occupancy_status("NOT_ACCEPTING_PASSENGERS"), do: :not_accepting_passengers

  defp parse_occupancy_status("NO_DATA_AVAILABLE"), do: :no_data_available

  defp parse_occupancy_status("NOT_BOARDABLE"), do: :not_boardable

  defp unix_to_local(timestamp) when is_integer(timestamp) do
    Parse.Timezone.unix_to_local(timestamp)
  end

  defp unix_to_local(timestamp) when is_float(timestamp) do
    Parse.Timezone.unix_to_local(trunc(timestamp))
  end

  defp unix_to_local(nil) do
    DateTime.utc_now()
  end
end
