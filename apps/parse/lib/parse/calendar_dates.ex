defmodule Parse.CalendarDates do
  @moduledoc """
  Parser for GTFS calendar_dates.txt
  """
  @behaviour Parse
  defstruct [:service_id, :date, :added, :holiday_name]

  def parse(blob) do
    blob
    |> BinaryLineSplit.stream!()
    |> SimpleCSV.decode()
    |> Enum.map(&parse_row/1)
  end

  defp parse_row(row) do
    %__MODULE__{
      service_id: :binary.copy(row["service_id"]),
      date: row["date"] |> Timex.parse!("{YYYY}{0M}{0D}") |> NaiveDateTime.to_date(),
      added: row["exception_type"] == "1",
      holiday_name: :binary.copy(row["holiday_name"])
    }
  end
end
