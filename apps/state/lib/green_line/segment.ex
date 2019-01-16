defmodule GreenLine.Segment do
  @moduledoc """
  Segments of the green line.
  """

  def by_latitude_longitude(latitude, longitude, bearing) do
    bearing = round(bearing)

    for lat <- clamps(latitude),
        lon <- clamps(longitude) do
      {lat, lon, bearing}
    end
    |> Enum.find_value(&by_key/1)
  end

  for map <-
        "priv/segments.csv"
        |> File.read!()
        |> BinaryLineSplit.stream!()
        |> SimpleCSV.decode() do
    segment = map["segment"]
    latitude = map["latitude"]
    longitude = map["longitude"]
    {bearing, ""} = Integer.parse(map["bearing"])

    def by_key({unquote(latitude), unquote(longitude), unquote(bearing)}) do
      unquote(segment)
    end
  end

  def by_key(_), do: nil

  def clamps(float) do
    # the current rounding in segments.csv is weird, so we try a bunch to see
    # if they work
    [Float.ceil(float, 5), Float.floor(float, 5), adjust_precision(float)]
    |> Enum.uniq()
    |> Enum.map(&Float.to_string/1)
  end

  defp adjust_precision(float) do
    # per https://github.com/dcodeIO/ProtoBuf.js/issues/273, converting a
    # double to a single-precision float loses some data, and when Elixir
    # converts it back to a double we get additional, but fake,
    # precision.  This rounding adjusts the extra precision out.
    Float.round(float / 4, 5) * 4
  end
end
