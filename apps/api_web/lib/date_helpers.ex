defmodule DateHelpers do
  @moduledoc """
  Helper functions for working with dates/times.
  """

  # UNIX epoch in gregorian seconds (seconds since year 0)
  @gregorian_offset :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})
  @doc """
  Adds a number of seconds to a Date.

  The seconds are relative to 12 hours before noon (local time) on the given
  date.

  ## Examples

      iex> DateHelpers.add_seconds_to_date(~D[2017-11-03], 86401)
      #DateTime<2017-11-04 00:00:01-04:00 EDT America/New_York>

      # falling back
      iex> DateHelpers.add_seconds_to_date(~D[2017-11-05], 3600)
      #DateTime<2017-11-05 01:00:00-05:00 EST America/New_York>

      iex> DateHelpers.add_seconds_to_date(~D[2017-11-05], 7200)
      #DateTime<2017-11-05 02:00:00-05:00 EST America/New_York>

      iex> DateHelpers.add_seconds_to_date(~D[2017-11-05], 43200)
      #DateTime<2017-11-05 12:00:00-05:00 EST America/New_York>

      # springing forward
      iex> DateHelpers.add_seconds_to_date(~D[2017-03-12], 3600)
      #DateTime<2017-03-12 00:00:00-05:00 EST America/New_York>

      iex> DateHelpers.add_seconds_to_date(~D[2017-03-12], 7200)
      #DateTime<2017-03-12 01:00:00-05:00 EST America/New_York>

      iex> DateHelpers.add_seconds_to_date(~D[2017-03-12], 43200)
      #DateTime<2017-03-12 12:00:00-04:00 EDT America/New_York>

      # if you're doing a lot of these, you can pre-convert to seconds
      iex> seconds = DateHelpers.unix_midnight_seconds(~D[2018-04-06])
      iex> DateHelpers.add_seconds_to_date(seconds, 61)
      #DateTime<2018-04-06 00:01:01-04:00 EDT America/New_York>
  """
  @spec add_seconds_to_date(Date.t() | non_neg_integer, non_neg_integer) :: DateTime.t()
  def add_seconds_to_date(date, seconds)

  def add_seconds_to_date(unix_seconds, seconds)
      when is_integer(unix_seconds) and is_integer(seconds) do
    RustDateTime.unix_to_local(unix_seconds + seconds)
  end

  def add_seconds_to_date(%Date{} = date, seconds) do
    date
    |> unix_midnight_seconds
    |> add_seconds_to_date(seconds)
  end

  @doc """
  Returns a UNIX timestamp for 12 hours before noon on the given day.
  """
  def unix_midnight_seconds(%Date{year: year, month: month, day: day}) do
    gregorian_noon = :calendar.datetime_to_gregorian_seconds({{year, month, day}, {12, 0, 0}})
    utc_noon = gregorian_noon - @gregorian_offset
    local_utc_noon = Parse.Timezone.unix_to_local(utc_noon)
    local_noon = %{local_utc_noon | hour: 12, minute: 0, second: 0}
    local_noon_unix = DateTime.to_unix(local_noon)
    twelve_hours = 12 * 3600
    local_noon_unix - twelve_hours
  end
end
