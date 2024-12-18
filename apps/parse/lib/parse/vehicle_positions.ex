defmodule Parse.VehiclePositions do
  @moduledoc """

  Parser for the VehiclePositions.pb GTFS-RT file.

  """
  @behaviour Parse

  def parse(<<31, 139, _::binary>> = blob) do
    # gzip encoded
    blob
    |> :zlib.gunzip()
    |> parse
  end

  def parse("{" <> _ = blob) do
    Parse.VehiclePositionsJson.parse(blob)
  end
end
