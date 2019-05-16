defmodule Parse.CommuterRailDepartures.JSON do
  @moduledoc """
  Parses an enhanced Trip Updates JSON file into a list of `%Model.Prediction{}` structs.

  This used to be only for Commuter Rail, but it's now generated for all modes.
  """
  @behaviour Parse
  import Parse.Helpers

  @impl true
  def parse(body) do
    body
    |> Jason.decode!()
    |> Map.get("entity")
    |> Enum.flat_map(&parse_entity/1)
  end

  def parse_entity(%{"trip_update" => %{"trip" => trip, "stop_time_update" => updates} = raw}) do
    base = base_prediction(trip, raw)

    for update <- updates do
      prediction(update, base)
    end
  end

  def parse_entity(%{}) do
    []
  end

  def base_prediction(trip, raw) do
    %Model.Prediction{
      trip_id: trip |> Map.get("trip_id") |> copy,
      route_id: trip |> Map.get("route_id") |> copy,
      direction_id: Map.get(trip, "direction_id"),
      vehicle_id: vehicle_id(raw),
      schedule_relationship: schedule_relationship(Map.get(trip, "schedule_relationship"))
    }
  end

  def prediction(update, base) do
    %{
      base
      | stop_id: update |> Map.get("stop_id") |> copy,
        arrival_time: time(Map.get(update, "arrival")),
        departure_time: time(Map.get(update, "departure")),
        stop_sequence: Map.get(update, "stop_sequence"),
        schedule_relationship: best_schedule_relationship(base.schedule_relationship, update),
        status: Map.get(update, "boarding_status"),
        track: track(update)
    }
  end

  defp time(%{"time" => time}) when is_integer(time) do
    Parse.Timezone.unix_to_local(time)
  end

  defp time(_) do
    nil
  end

  defp vehicle_id(%{"vehicle" => %{"id" => id}}), do: id
  defp vehicle_id(_), do: nil

  defp best_schedule_relationship(relationship, update) do
    if update_relationship = schedule_relationship(Map.get(update, "schedule_relationship")) do
      update_relationship
    else
      relationship
    end
  end

  for relationship <- ~w(added skipped unscheduled no_data)a do
    binary = relationship |> Atom.to_string() |> String.upcase()
    defp schedule_relationship(unquote(binary)), do: unquote(relationship)
  end

  defp schedule_relationship("CANCELED"), do: :cancelled
  defp schedule_relationship(_), do: nil

  defp track(%{"track" => value}) do
    copy(value)
  end

  defp track(%{"platform_id" => platform}) when is_binary(platform) do
    [_, track] = :binary.split(platform, "-")
    copy(String.replace_prefix(track, "0", ""))
  end

  defp track(_) do
    nil
  end
end
