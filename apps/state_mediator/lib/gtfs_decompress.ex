defmodule GtfsDecompress do
  @moduledoc """

  Wrapping the State API (new_state/size), we decompress the GTFS zip
  file and trigger events for the downstream state handlers to import.

  """
  require Logger

  @filename_prefixes ~w(calendar
                        calendar_attributes
                        calendar_dates
                        feed_info
                        multi_route_trips
                        routes
                        route_patterns
                        shapes
                        stop_times
                        stops
                        trips
                        facilities
                        facilities_properties
                        directions
                        lines
                        transfers)

  def filenames do
    for filename <- @filename_prefixes do
      "#{filename}.txt"
    end
  end

  def new_state(body, _timeout \\ 5000) do
    _ = Logger.debug("Received GTFS file...")
    {:ok, handle} = :zip.zip_open(body, [:memory])

    for filename <- filenames() do
      {:ok, body} = read_file(filename, handle)
      Events.publish({:fetch, filename}, body)
    end

    :ok = :zip.zip_close(handle)

    :ok
  end

  def size do
    State.Schedule.size()
  end

  defp read_file(gtfs_filename, handle) do
    _ = Logger.debug(fn -> "Trying to read #{gtfs_filename}" end)

    case :zip.zip_get(to_charlist(gtfs_filename), handle) do
      {:ok, {_, body}} ->
        {:ok, body}

      _ ->
        {:error, {:missing_gtfs_file, gtfs_filename}}
    end
  end
end
