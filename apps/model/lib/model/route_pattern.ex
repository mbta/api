defmodule Model.RoutePattern do
  @moduledoc """
  A variant of service run within a single route_id
  [GTFS `route_patterns.txt`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#route_patternstxt)
  """

  use Recordable, [
    :id,
    :route_id,
    :direction_id,
    :name,
    :time_desc,
    :typicality,
    :sort_order,
    :representative_trip_id,
    :is_canonical
  ]

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id,
          route_id: Model.Route.id(),
          direction_id: Model.Direction.id(),
          name: String.t(),
          time_desc: String.t() | nil,
          typicality: 0..5,
          sort_order: integer(),
          representative_trip_id: Model.Trip.id(),
          is_canonical: 0..2 | nil
        }
end
