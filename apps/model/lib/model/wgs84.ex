defmodule Model.WGS84 do
  @moduledoc """
  A [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084) latitude and
  longitude
  """

  @typedoc """
  Degrees East, in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084)
  coordinate system.
  """
  @type latitude :: float

  @typedoc """
  Degrees East, in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#Longitudes_on_WGS.C2.A084)
  coordinate system.
  """
  @type longitude :: float
end
