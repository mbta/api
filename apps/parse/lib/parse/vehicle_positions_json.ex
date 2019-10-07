defmodule Parse.VehiclePositionsJson do
  @moduledoc """

  Parses an enhanced Vehicle Position JSON file into a list of `%Model.Vehicle{}` structs.

  """
  alias Model.Vehicle

  def parse(body) do
    body
    |> Jason.decode!(strings: :copy)
    |> Map.get("entity")
    |> Enum.flat_map(&parse_entity/1)
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
        consist: parse_consist(Map.get(vehicle, "consist"))
      }
    ]
  end

  def parse_entity(%{}) do
    []
  end

  defp parse_consist([_ | _] = consist) do
    consist
    |> Enum.map(fn %{"label" => car_label} -> car_label end)
    |> MapSet.new()
  end

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

  defp unix_to_local(timestamp) when is_integer(timestamp) do
    Parse.Timezone.unix_to_local(timestamp)
  end

  defp unix_to_local(nil) do
    DateTime.utc_now()
  end
end
