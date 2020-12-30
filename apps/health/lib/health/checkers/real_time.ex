defmodule Health.Checkers.RealTime do
  @moduledoc """
  Health check which makes sure that real-time data (vehicle positions and
  predictions) aren't stale.
  """
  @stale_data_seconds 15 * 60
  @current_time_fetcher &DateTime.utc_now/0

  def current do
    updated_timestamps = State.Metadata.updated_timestamps()

    [prediction: updated_timestamps.prediction, vehicle: updated_timestamps.vehicle]
  end

  def healthy?(current_time_fetcher \\ @current_time_fetcher) do
    updated_timestamps = State.Metadata.updated_timestamps()
    current_time = current_time_fetcher.()

    Enum.all?([:prediction, :vehicle], fn feed ->
      DateTime.diff(current_time, updated_timestamps[feed]) < @stale_data_seconds
    end)
  end
end
