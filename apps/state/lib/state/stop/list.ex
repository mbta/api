defmodule State.Stop.List do
  @moduledoc """
  Allows constructing a list of `Model.Stop.t` in a radius around a `latitude` and `longitude`.
  """

  alias Model.WGS84

  @typedoc """
  The distance is in degrees as if latitude and longitude were projected onto a flat 2d plane and normal
  Pythagorean distance was calculated.  Over the region MBTA serves, `0.02` degrees is approximately `1` mile.
  Defaults to `0.01` degrees (approximately a half mile).
  """
  @type radius :: float

  @typedoc """
  An opaque collection of `Model.Stop.t` that can be used to calculate the stops `around/4` a position.
  """
  @opaque t :: :rstar.rtree()

  @spec new([Model.Stop.t()]) :: t
  def new(list_of_stops) do
    list_of_stops
    |> Stream.map(&point_for_stop/1)
    |> Enum.reduce(:rstar.new(2), &insert_point/2)
  end

  @spec around(t, WGS84.latitude(), WGS84.longitude(), radius) :: [Model.Stop.t()]
  def around(l, latitude, longitude, radius \\ 0.01) do
    l
    |> :rstar.search_around(:rstar_geometry.point2d(latitude, longitude, nil), radius)
    |> Enum.map(&:rstar_geometry.value/1)
  end

  @spec point_for_stop(Model.Stop.t()) :: :rstar.geometry()
  defp point_for_stop(stop) do
    :rstar_geometry.point2d(stop.latitude, stop.longitude, stop.id)
  end

  @spec insert_point(:rstar.geometry(), t) :: t
  defp insert_point(point, tree) do
    :rstar.insert(tree, point)
  end
end
