defmodule Model.Route do
  @moduledoc """
  Route represents a line in the transit system.
  """

  use Recordable, [
    :id,
    :agency_id,
    :short_name,
    :long_name,
    :description,
    :fare_class,
    :type,
    :color,
    :text_color,
    :sort_order,
    :line_id,
    :listed_route,
    direction_names: [nil, nil],
    direction_destinations: [nil, nil]
  ]

  @typedoc """
  The color must be be a six-character hexadecimal number, for example, `00FFFF`. If no color is specified, the default
  route color is white (`FFFFFF`).
  """
  @type color :: String.t()
  @type id :: String.t()
  @typedoc """
  | Value | Name       | Description                                                       |
  |-------|------------|-------------------------------------------------------------------|
  | `0`   | Light Rail | Any light rail or street level system within a metropolitan area. |
  | `1`   | Subway     | Any underground rail system within a metropolitan area.           |
  | `2`   | Rail       | Used for intercity or long-distance travel.                       |
  | `3`   | Bus        | Used for short- and long-distance bus routes.                     |
  | `4`   | Ferry      | Used for short- and long-distance boat service.                   |

  See
  [GTFS `routes.txt` `route_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  """
  @type route_type :: 0 | 1 | 2 | 3 | 4

  @typedoc """
  * `:id` - Unique ID
  * `:agency_id` - Unique ID of the agency
  * `:color` - A color that corresponds to the route, such as the line color on a map.  The color difference between
      `:color` and `:text_color` should provide sufficient contrast when viewed on a black and white screen. The
      [W3C Techniques for Accessibility Evaluation And Repair Tools document](https://www.w3.org/TR/AERT#color-contrast)
      offers a useful algorithm for evaluating color contrast. There are also helpful online tools for choosing
      contrasting colors, including the
      [snook.ca Color Contrast Check application](http://snook.ca/technical/colour_contrast/colour.html#fg=33FF33,bg=333333).
      See
      [GTFS `routes.txt` `route_color`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:description` - Details about stops, schedule, and/or service.  See
      [GTFS `routes.txt` `route_desc`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:long_name` - The full name of a route. This name is generally more descriptive than the `:short_name` and will
      often include the route's destination or stop. See
      [GTFS `routes.txt` `route_long_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:short_name` - This will often be a short, abstract identifier like "32", "100X", or "Green" that riders use to
      identify a route, but which doesn't give any indication of what places the route serves. At least one of
      `:short_name` or `:long_name` must be specified. See
      [GTFS `routes.txt` `route_short_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:fare_class` - Specifies the fare type of the route, which can differ from the service category.
  * `:sort_order` - routes are sorted in ascending order of this field.
  * `:text_color` - A legible color to use for text drawn against a background of `:color`.  If no color is specified,
      the default text color is black (`000000`). The color difference between `:color` and `:text_color` should provide
      sufficient contrast when viewed on a black and white screen.  See
      [GTFS `routes.txt` `route_text_color`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:type` - Type of vehicle used on route.  See
      [GTFS `routes.txt` `route_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
  * `:line_id` - References `line_id` values from `lines.txt`. Indicates in which grouping of routes this route belongs
  * `:listed_route` - Indicates whether route should be included in a public-facing list of all routes.
  * `:direction_names` - names of direction ids for this route in ascending ordering starting at `0` for the first index.
  * `:direction_destinations` - destinations for direction ids for this route in ascending ordering starting at `0` 
      for the first index.
  """
  @type t :: %__MODULE__{
          id: id,
          agency_id: id,
          color: color,
          description: String.t(),
          long_name: String.t() | nil,
          short_name: String.t() | nil,
          fare_class: String.t() | nil,
          sort_order: non_neg_integer,
          text_color: color,
          type: route_type,
          line_id: id,
          listed_route: boolean,
          direction_names: [String.t() | nil],
          direction_destinations: [String.t() | nil]
        }
end
