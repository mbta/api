defmodule Parse.GtfsRt.TripUpdates do
  @moduledoc """
  Parser for the GTFS-RT TripUpdates JSON output 

  We formerly parsed GTFS-RT protobufs in this module as well
  """
  @behaviour Parse
  use Timex

  def parse("{" <> _ = blob) do
    Parse.GtfsRt.TripUpdatesEnhancedJson.parse(blob)
  end
end
