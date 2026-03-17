defmodule Model.StopEvent do
  @moduledoc """
  The actual time a `vehicle_id` `arrived` at and/or `departed` from a `stop_sequence` in a trip (`trip_id`) going a direction (`direction_id`) along a route (`route_id`). A stop event is the actual time a vehicle arrived at or departed from a stop, as opposed to the predicted (`Model.Prediction`) or scheduled (`Model.Schedule`) time of arrival or departure.
  """

  use Recordable, [
    :id,
    :vehicle_id,
    :start_date,
    :trip_id,
    :direction_id,
    :route_id,
    :revenue,
    :stop_id,
    :stop_sequence,
    :arrived,
    :departed
  ]

  @typedoc """
  * `:id` - Composite key: `{start_date}-{trip_id}-{route_id}-{vehicle_id}-{stop_sequence}`.
  * `:vehicle_id` - The vehicle serving this trip. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `VehiclePosition` `vehicle` `id`](https://gtfs.org/documentation/realtime/reference/#message-vehicledescriptor).
  * `:start_date` - The [service date](https://gtfs.org/getting-started/features/base/#service-dates) for which the `trip_id` was scheduled. Often, this matches the calendar date. Early morning trips may use a `start_date` equivalent to the previous calendar date. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `VehiclePosition` `trip` `start_date`](https://gtfs.org/documentation/realtime/reference/#message-tripdescriptor).
  * `:trip_id` - The trip that the vehicle (`vehicle_id`) is traveling. See [GTFS Schedule `trips.txt` `trip_id`](https://gtfs.org/documentation/schedule/reference/#tripstxt)
  * `:direction_id` - The direction along the route (`route_id`) that the trip (`trip_id`) is traveling.  See
      [GTFS `trips.txt` `direction_id`](https://gtfs.org/documentation/schedule/reference/#tripstxt).
  * `:route_id` - The route that the trip `trip_id` is traveling in a direction `direction_id`.  See
      [GTFS `routes.txt` `route_id`](https://gtfs.org/documentation/schedule/reference/#routestxt)
  * `:revenue` - Whether the trip generates revenue. `false` indicates that a vehicle will not accept passengers.  See [MBTA GTFS Realtime Documentation](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs-realtime.md#non-revenue-trips).
  * `:stop_id` - Stop that the vehicle `vehicle_id` arrived at and/or departed from. See
      [GTFS Schedule `stops.txt` `stop_id`](https://gtfs.org/documentation/schedule/reference/#stopstxt).
  * `:stop_sequence` - The sequence of the stop along the `trip_id`.  The stop sequence increases monotonically but values need not be consecutive.
      See [GTFS `stop_times.txt` `stop_sequence`](https://gtfs.org/documentation/schedule/reference/#stop_timestxt).
  * `:arrived` - When the vehicle arrived at the stop as a time-zone aware [RFC 3339 datetime](https://datatracker.ietf.org/doc/html/rfc3339#page-10). `nil` if the first stop (`stop_id`) on the trip (`trip_id`).
  * `:departed` - When the vehicle departed from the stop as time-zone aware [RFC 3339 datetime](https://datatracker.ietf.org/doc/html/rfc3339#page-10). `nil` if the last stop (`stop_id`) on the trip (`trip_id`).
  """

  @type t :: %__MODULE__{
          id: String.t(),
          vehicle_id: Model.Vehicle.id(),
          start_date: Date.t(),
          trip_id: Model.Trip.id(),
          direction_id: Model.Direction.id(),
          route_id: Model.Route.id(),
          stop_id: Model.Stop.id(),
          stop_sequence: Model.Schedule.stop_sequence(),
          revenue: :REVENUE | :NON_REVENUE,
          arrived: DateTime.t() | nil,
          departed: DateTime.t() | nil
        }
end
