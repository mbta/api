defmodule Parse.StopTimes do
  @moduledoc """
  Parses the GTFS stop_times.txt file.
  """
  @behaviour Parse
  import NimbleParsec
  import Parse.Helpers

  # credo:disable-for-lines:4 Credo.Check.Refactor.PipeChainStart
  defparsec(
    :time,
    integer(min: 1, max: 2)
    |> ignore(string(":"))
    |> integer(2)
    |> ignore(string(":"))
    |> integer(2)
  )

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
      stop_headsign: optional_copy(row["stop_headsign"]),
      pickup_type: pick_drop_type(row["pickup_type"]),
      drop_off_type: pick_drop_type(row["drop_off_type"]),
      timepoint?: row["timepoint"] != "0"
    }
  end

  defp convert_time(_, "1"), do: nil

  defp convert_time(binary, _) do
    {:ok, [h, m, s], _, _, _, _} = time(binary)
    3600 * h + 60 * m + s
  end

  defp pick_drop_type("0"), do: 0
  defp pick_drop_type("1"), do: 1
  defp pick_drop_type("2"), do: 2
  defp pick_drop_type("3"), do: 3

  defp parse_rows(rows, nil) do
    rows
    |> Enum.map(&parse_row/1)
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

  defp position_last_row(list) do
    [last | rest] = Enum.reverse(list)
    Enum.reverse([%{last | position: :last} | rest])
  end
end
