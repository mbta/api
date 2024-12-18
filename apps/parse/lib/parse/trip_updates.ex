defmodule Parse.TripUpdates do
  @moduledoc """
  Parser for the GTFS-RT TripUpdates protobuf output.
  """
  @behaviour Parse
  use Timex

  def parse("{" <> _ = blob) do
    Parse.CommuterRailDepartures.JSON.parse(blob)
  end
end
