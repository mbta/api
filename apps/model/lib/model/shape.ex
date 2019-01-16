defmodule Model.Shape do
  @moduledoc """
  Shape represents a combination of
  [a shape from GTFS](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#shapestxt) and a variant
  from [HASTUS](http://www.giro.ca/en/solutions/bus-metro-tram).
  Trips that are grouped under the same route can go to different stops: a pattern
  describes one of those patterns of stops.

  Multiple shapes occur for the same `route_id` to represent branches on rail lines.
  """

  use Recordable, [:id, :route_id, :direction_id, :name, :polyline, :priority]

  @type id :: String.t()

  @typedoc """
  [Encoded Polyline Algorithm Format](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
  """
  @type polyline :: String.t()

  @typedoc """
  The priority for showing a `t` for a given `route_id`.  Negative priority is not important enough to show as they only
  **MAY** be used.
  """
  @type priority :: integer

  @typedoc """
  * `id` - Unique ID for this shape.
  * `route_id` - the route described by this shape
  * `direction_id` - which direction around a `Model.Trip.t` this shape is for.
  * `name` -  Name of the shape, which comes from either the `Model.Trip.t` `headsign` or the variant headsign.
  * `polyline` - The encoded latiatude and longitude points in the shape.
  * `priority` - The priority for showing the shape for a given route.
  """
  @type t :: %__MODULE__{
          id: id,
          route_id: Model.Route.id(),
          direction_id: Model.Direction.id(),
          name: String.t(),
          polyline: polyline,
          priority: priority
        }
end
