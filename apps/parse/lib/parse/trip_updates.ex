defmodule Parse.TripUpdates do
  @moduledoc """
  Parser for the GTFS-RT TripUpdates protobuf output.
  """
  @behaviour Parse
  alias Model.Prediction
  use Timex
  import :binary, only: [copy: 1]

  def parse("{" <> _ = blob) do
    Parse.CommuterRailDepartures.JSON.parse(blob)
  end

  def parse(blob) do
    blob
    |> Parse.Realtime.FeedMessage.decode()
    |> (fn message -> message.entity end).()
    |> Stream.map(fn entity -> entity.trip_update end)
    |> Stream.flat_map(&parse_trip_update/1)
  end

  def parse_trip_update(update) do
    base = %Prediction{
      trip_id: copy(update.trip.trip_id),
      route_id: copy(update.trip.route_id),
      direction_id: update.trip.direction_id,
      vehicle_id: vehicle_id(update.vehicle),
      schedule_relationship: trip_relationship(update.trip.schedule_relationship),
      revenue: parse_revenue(Map.get(update.trip, :revenue, true))
    }

    update.stop_time_update
    |> Stream.reject(&is_nil(&1.stop_id))
    |> Enum.map(&parse_stop_time_update(&1, base))
    |> remove_last_departure_time([])
  end

  defp parse_stop_time_update(update, %Prediction{} = base) do
    %{
      base
      | stop_id: copy(update.stop_id),
        stop_sequence: update.stop_sequence,
        arrival_time: parse_stop_time_event(update.arrival),
        arrival_uncertainty: parse_uncertainty(update.arrival),
        departure_time: parse_stop_time_event(update.departure),
        departure_uncertainty: parse_uncertainty(update.departure),
        schedule_relationship:
          stop_time_relationship(update.schedule_relationship, base.schedule_relationship)
    }
  end

  def parse_stop_time_event(%{time: seconds}) when is_integer(seconds) and seconds > 0 do
    Parse.Timezone.unix_to_local(seconds)
  end

  def parse_stop_time_event(_) do
    nil
  end

  defp parse_uncertainty(%{uncertainty: uncertainty}) when is_integer(uncertainty) do
    uncertainty
  end

  defp parse_uncertainty(_), do: nil

  defp vehicle_id(%{id: id}), do: id
  defp vehicle_id(_), do: nil

  defp trip_relationship(nil) do
    nil
  end

  defp trip_relationship(:SCHEDULED) do
    nil
  end

  defp trip_relationship(:ADDED) do
    :added
  end

  defp trip_relationship(:UNSCHEDULED) do
    :unscheduled
  end

  defp trip_relationship(:CANCELED) do
    # add the extra L
    :cancelled
  end

  defp stop_time_relationship(:SCHEDULED, nil) do
    nil
  end

  defp stop_time_relationship(:SKIPPED, nil) do
    :skipped
  end

  defp stop_time_relationship(:NO_DATA, nil) do
    :no_data
  end

  defp stop_time_relationship(_relationship, existing) do
    existing
  end

  defp remove_last_departure_time([], _) do
    []
  end

  defp remove_last_departure_time([last], acc) do
    last = %{last | departure_time: nil}
    Enum.reverse([last | acc])
  end

  defp remove_last_departure_time([first | rest], acc) do
    remove_last_departure_time(rest, [first | acc])
  end

  defp parse_revenue(false), do: :NON_REVENUE

  defp parse_revenue(_), do: :REVENUE
end
