defmodule Parse.Time do
  @moduledoc """
  Helpers for times and dates
  """

  @spec now() :: DateTime.t()
  def now do
    now_unix = System.system_time(:second)
    {:ok, dt} = FastLocalDatetime.unix_to_datetime(now_unix, "America/New_York")
    dt
  end

  @spec service_date() :: Date.t()
  @spec service_date(DateTime.t()) :: Date.t()
  def service_date(current_time \\ DateTime.utc_now())

  def service_date(%{year: _} = current_time) do
    current_unix = DateTime.to_unix(current_time)
    back_three_hours = current_unix - 10_800
    {:ok, dt} = FastLocalDatetime.unix_to_datetime(back_three_hours, "America/New_York")
    DateTime.to_date(dt)
  end

  def service_date(%Timex.AmbiguousDateTime{before: before}) do
    service_date(before)
  end
end
