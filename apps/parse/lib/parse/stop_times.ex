defmodule Parse.StopTimes do
  @moduledoc """
  Parses the GTFS stop_times.txt file.
  """
  @behaviour Parse
  @compile :native
  @compile {:hipe, [:o3]}

  import :binary, only: [copy: 1]

  alias Model.{Schedule, Trip}
  require Logger

  def parse(blob, trip_fn \\ nil) do
    blob
    |> BinaryLineSplit.stream!()
    |> SimpleCSV.stream()
    |> Stream.chunk_by(& &1["trip_id"])
    |> Stream.flat_map(&parse_rows(&1, trip_fn))
  end

  def parse_row(row) do
    %Schedule{
      trip_id: copy(row["trip_id"]),
      stop_id: copy(row["stop_id"]),
      arrival_time: convert_time(row["arrival_time"], row["drop_off_type"]),
      departure_time: convert_time(row["departure_time"], row["pickup_type"]),
      stop_sequence: String.to_integer(row["stop_sequence"]),
      pickup_type: String.to_integer(row["pickup_type"]),
      drop_off_type: String.to_integer(row["drop_off_type"]),
      timepoint?: row["timepoint"] != "0",
      stop_n_trip: {copy(row["stop_id"]), copy(row["trip_id"])}
    }
  end

  defp convert_time(_, "1"), do: nil

  defp convert_time(str, _) do
    str
    |> String.split(":")
    |> Enum.map(&String.to_integer/1)
    # [hour, minute, second] in seconds
    |> Enum.zip([3600, 60, 1])
    |> Enum.map(fn {part, mult} -> part * mult end)
    |> Enum.sum()
  end

  defp parse_rows(rows, nil) do
    rows
    |> Enum.map(&parse_row/1)
    |> Enum.sort_by(&Map.get(&1, :stop_sequence))
    |> position_first_row
    |> position_last_row
  end

  defp parse_rows([%{"trip_id" => trip_id} | _] = rows, trip_fn) do
    case trip_fn.(trip_id) do
      nil ->
        []

      %Trip{} = trip ->
        rows
        |> parse_rows(nil)
        |> Enum.map(
          &%{
            &1
            | route_id: trip.route_id,
              direction_id: trip.direction_id,
              service_id: trip.service_id
          }
        )
    end
  end

  defp position_first_row([first | rest]) do
    first = %{first | position: :first}
    [first | rest]
  end

  defp position_last_row([last]) do
    [%{last | position: :last}]
  end

  defp position_last_row([first | rest]) do
    [first | position_last_row(rest)]
  end
end
