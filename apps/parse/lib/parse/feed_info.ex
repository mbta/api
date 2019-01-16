defmodule Parse.FeedInfo do
  @moduledoc false
  use Parse.Simple
  alias Model.Feed

  def parse_row(row) do
    %Feed{
      name: copy(row["feed_publisher_name"]),
      version: copy(row["feed_version"]),
      start_date: parse_date(row["feed_start_date"]),
      end_date: parse_date(row["feed_end_date"])
    }
  end

  defp parse_date(str) do
    str
    |> Timex.parse!("{YYYY}{0M}{0D}")
    |> NaiveDateTime.to_date()
  end
end
