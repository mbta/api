defmodule Parse.Trips do
  @moduledoc """
  Parses `trips.txt` CSV from GTFS zip

      "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","trip_route_type"
      "Logan-22","Logan-Weekday","Logan-22-Weekday-trip","Loop","",0,"","",1,""

  """

  use Parse.Simple
  alias Model.Trip

  @doc """
  Parses (non-header) row of `trips.txt`

  ## Columns

  * `"trip_id"` - `Model.Trip.id`
  * `"service_id` - `Model.Service.id`
  * `"route_id"` - `Model.Route.id`
  * `"shape_id` - `Model.Shape.id`
  * `"trip_headsign"` - `Model.Trip.t` `headsign`
  * `"trip_short_name"` - `Model.Trip.t` `name`
  * `"direction_id"` - `Model.Trip.t` `direction`
  * `"block_id"` - `Model.Trip.t` `block_id`
  * `"wheelchair_accessible"` - `Model.Trip.t` `wheelchair_accessible`
  * `"trip_route_type" - `Model.Route.route_type | nil`
  * `"route_pattern_id" - `Model.RoutePattern.t`

  """
  def parse_row(row) do
    %Trip{
      id: copy(row["trip_id"]),
      service_id: copy(row["service_id"]),
      route_id: copy(row["route_id"]),
      shape_id: copy(row["shape_id"]),
      headsign: copy(row["trip_headsign"]),
      name: copy(row["trip_short_name"]),
      direction_id: String.to_integer(row["direction_id"]),
      block_id: copy(row["block_id"]),
      wheelchair_accessible: String.to_integer(row["wheelchair_accessible"]),
      route_type: trip_route_type(row["trip_route_type"]),
      bikes_allowed: bikes_allowed(row["bikes_allowed"]),
      route_pattern_id: copy_if_not_blank(row["route_pattern_id"])
    }
  end

  for route_type <- 0..4 do
    defp trip_route_type(unquote(Integer.to_string(route_type))), do: unquote(route_type)
  end

  defp trip_route_type(_), do: nil

  defp bikes_allowed(nil), do: 0
  defp bikes_allowed(""), do: 0
  defp bikes_allowed(allowed), do: String.to_integer(allowed)

  defp copy_if_not_blank(binary) when byte_size(binary) > 0 do
    copy(binary)
  end

  defp copy_if_not_blank(_), do: nil
end
