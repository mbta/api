defmodule Parse.VehiclePositions do
  @moduledoc """

  Parses an enhanced Vehicle Position JSON file into a list of `%Model.Vehicle{}` structs.

  """
  @behaviour Parse
  alias Model.Vehicle
  import Parse.Helpers

  @impl true
  def parse(body) do
    body
    |> Jason.decode!()
    |> Map.get("entity")
    |> Enum.flat_map(&parse_entity/1)
  end

  def parse_entity(
        %{
          "vehicle" => %{
            "position" => position,
            "trip" => trip,
            "vehicle" => vehicle,
            "timestamp" => timestamp
          }
        } = entity
      ) do
    data = Map.get(entity, "vehicle")

    [
      %Vehicle{
        id: optional_field_copy(vehicle, "id"),
        trip_id: optional_field_copy(trip, "trip_id"),
        route_id: optional_field_copy(trip, "route_id"),
        direction_id: optional_field_copy(trip, "direction_id"),
        stop_id: Map.get(data, "stop_id"),
        label: optional_field_copy(vehicle, "label"),
        latitude: optional_field_copy(position, "latitude"),
        longitude: optional_field_copy(position, "longitude"),
        bearing: optional_field_copy(position, "bearing"),
        speed: optional_field_copy(position, "speed"),
        current_status: parse_status(Map.get(data, "current_status")),
        current_stop_sequence: Map.get(data, "current_stop_sequence"),
        updated_at: unix_to_local(timestamp)
      }
    ]
  end

  def parse_entity(%{}) do
    []
  end

  defp optional_copy("") do
    # empty string is a default value and should be treated as a not-provided
    # value
    nil
  end

  defp optional_copy(value) do
    copy(value)
  end

  defp optional_field_copy(%{} = struct, field) do
    optional_copy(Map.get(struct, field))
  end

  defp optional_field_copy(_, _) do
    nil
  end

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
