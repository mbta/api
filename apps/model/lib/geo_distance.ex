defmodule GeoDistance do
  @moduledoc """
  Helper functions for working with geographic distances.
  """
  @degrees_to_radians 0.0174533
  @twice_earth_radius_miles 7918

  @doc "Returns the Haversine distance (in miles) between two latitude/longitude pairs"
  @spec distance(number, number, number, number) :: float
  def distance(latitude, longitude, latitude2, longitude2) do
    # Haversine distance
    a =
      0.5 - :math.cos((latitude2 - latitude) * @degrees_to_radians) / 2 +
        :math.cos(latitude * @degrees_to_radians) * :math.cos(latitude2 * @degrees_to_radians) *
          (1 - :math.cos((longitude2 - longitude) * @degrees_to_radians)) / 2

    @twice_earth_radius_miles * :math.asin(:math.sqrt(a))
  end

  @doc "Returns a comparison function based on the distance between two points"
  @spec cmp(number, number) :: (%{latitude: number, longitude: number} -> float)
  def cmp(latitude, longitude) do
    fn %{latitude: latitude2, longitude: longitude2} ->
      GeoDistance.distance(latitude, longitude, latitude2, longitude2)
    end
  end
end
