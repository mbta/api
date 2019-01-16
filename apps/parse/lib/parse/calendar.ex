defmodule Parse.Calendar do
  @moduledoc """

  Parse a calendar.txt
  (https://developers.google.com/transit/gtfs/reference#calendartxt) file
  into a simple struct.

  """
  @behaviour Parse
  defstruct [:service_id, :days, :start_date, :end_date]
  use Timex

  def parse(blob) do
    blob
    |> BinaryLineSplit.stream!()
    |> SimpleCSV.decode()
    |> Enum.map(&parse_row/1)
  end

  defp parse_row(row) do
    %__MODULE__{
      service_id: :binary.copy(row["service_id"]),
      start_date: parse_date(row["start_date"]),
      end_date: parse_date(row["end_date"]),
      days: parse_days(row)
    }
  end

  defp parse_date(date) do
    date
    |> Timex.parse!("{YYYY}{0M}{0D}")
    |> NaiveDateTime.to_date()
  end

  defp parse_days(row) do
    []
    |> add_day(row["sunday"], 7)
    |> add_day(row["saturday"], 6)
    |> add_day(row["friday"], 5)
    |> add_day(row["thursday"], 4)
    |> add_day(row["wednesday"], 3)
    |> add_day(row["tuesday"], 2)
    |> add_day(row["monday"], 1)
  end

  defp add_day(result, "1", value) do
    [value | result]
  end

  defp add_day(result, _, _) do
    result
  end
end
