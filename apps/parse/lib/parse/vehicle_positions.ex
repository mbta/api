defmodule Parse.VehiclePositions do
  @moduledoc """

  Parser for the VehiclePositions.pb GTFS-RT file.

  """
  @behaviour Parse
  alias Model.Vehicle
  alias Parse.Realtime.FeedMessage
  import Parse.Helpers

  def parse("{" <> _ = blob) do
    Parse.VehiclePositionsJson.parse(blob)
  end

  def parse(blob) do
    blob
    |> FeedMessage.decode()
    |> (fn message -> message.entity end).()
    |> Stream.map(fn entity -> entity.vehicle end)
    |> Stream.map(&parse_vehicle_update/1)
  end

  def parse_vehicle_update(update) do
    %Vehicle{
      id: optional_field_copy(update.vehicle, :id),
      trip_id: optional_field_copy(update.trip, :trip_id),
      route_id: optional_field_copy(update.trip, :route_id),
      direction_id: update.trip && update.trip.direction_id,
      stop_id: optional_copy(update.stop_id),
      label: optional_field_copy(update.vehicle, :label),
      latitude: update.position && update.position.latitude,
      longitude: update.position && update.position.longitude,
      bearing: update.position && update.position.bearing,
      speed: update.position && update.position.speed,
      current_status: current_status(update.current_status),
      current_stop_sequence: update.current_stop_sequence,
      updated_at: unix_to_local(update.timestamp),
      occupancy_status: occupancy_status(update.occupancy_status)
    }
  end

  defp optional_field_copy(%{} = struct, field) do
    optional_copy(Map.get(struct, field))
  end

  defp optional_field_copy(_, _) do
    nil
  end

  defp current_status(nil) do
    :in_transit_to
  end

  defp current_status(:IN_TRANSIT_TO) do
    :in_transit_to
  end

  defp current_status(:INCOMING_AT) do
    :incoming_at
  end

  defp current_status(:STOPPED_AT) do
    :stopped_at
  end

  defp occupancy_status(nil), do: nil

  defp occupancy_status(:EMPTY), do: :empty

  defp occupancy_status(:MANY_SEATS_AVAILABLE), do: :many_seats_available

  defp occupancy_status(:FEW_SEATS_AVAILABLE), do: :few_seats_available

  defp occupancy_status(:STANDING_ROOM_ONLY), do: :standing_room_only

  defp occupancy_status(:CRUSHED_STANDING_ROOM_ONLY), do: :crushed_standing_room_only

  defp occupancy_status(:FULL), do: :full

  defp occupancy_status(:NOT_ACCEPTING_PASSENGERS), do: :not_accepting_passengers

  defp unix_to_local(timestamp) when is_integer(timestamp) do
    Parse.Timezone.unix_to_local(timestamp)
  end

  defp unix_to_local(nil) do
    DateTime.utc_now()
  end
end
