defmodule Parse.Timezone do
  @moduledoc """
  Maintains the local timezone name, offset, and abbreviation.

  The parsers use this to convert a UNIX timestamp into the appropriate local DateTime in an efficient manner.
  """
  @doc """
  Given a unix timestamp, converts it to the appropriate local timezone.

  iex> unix_to_local(1522509910)
  #DateTime<2018-03-31 11:25:10-04:00 EDT America/New_York>
  """
  def unix_to_local(unix_timestamp) when is_integer(unix_timestamp) do
    {:ok, datetime} = FastLocalDatetime.unix_to_datetime(unix_timestamp, "America/New_York")
    datetime
  end
end
