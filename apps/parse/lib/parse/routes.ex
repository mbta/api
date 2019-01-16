defmodule Parse.Routes do
  @moduledoc """
  Parses `routes.txt` CSV from GTFS zip

    route_id,agency_id,route_short_name,route_long_name,route_desc,route_fare_class,route_type,route_url,route_color,route_text_color,route_sort_order,line_id,listed_route
    Boat-F1,1,,Hingham/Hull Ferry,Ferry,Ferry,4,https://www.mbta.com/schedules/Boat-F1,008EAA,FFFFFF,1000002,,
  """

  use Parse.Simple
  alias Model.Route

  @doc """
  Parses (non-header) row of `routes.txt`

  ## Columns

  * `"route_id"` - `Model.Route.t` - `id`
  * `"agency_id"` - `Model.Route.t` - `agency_id`
  * `"route_short_name"` - `Model.Route.t` `short_name`
  * `"route_long_name"` - `Model.Route.t` `long_name`
  * `"route_desc"` - `Model.Route.t` `description`
  * `"route_fare_class"` - `Model.Route.t` `fare_class`
  * `"route_type"` - `Model.Route.t` `type`
  * `"route_text_color"` - `Model.Route.t` `text_color`
  * `"route_sort_order"` - `Model.Route.t` `sort_order`
  * `"line_id"` - `Model.Route.t` - `line_id`
  * `"listed_route"` - `Model.Route.t` `listed_route`

  """
  def parse_row(row) do
    %Route{
      id: copy(row["route_id"]),
      agency_id: copy(row["agency_id"]),
      short_name: copy(row["route_short_name"]),
      long_name: copy(row["route_long_name"]),
      description: copy(row["route_desc"]),
      fare_class: copy(row["route_fare_class"]),
      type: String.to_integer(row["route_type"]),
      color: copy(row["route_color"]),
      text_color: copy(row["route_text_color"]),
      sort_order: String.to_integer(row["route_sort_order"]),
      line_id: copy(row["line_id"]),
      listed_route: listed_route(row["listed_route"], row["agency_id"]),
      direction_names: [nil, nil],
      direction_destinations: [nil, nil]
    }
  end

  defp listed_route("1", _), do: false
  defp listed_route(_, _), do: true
end
