defmodule Model.StopEvent do
  @moduledoc """
  The actual `arrival_time` and `departure_time` of a `vehicle_id` to/from a `stop_sequence` in a `trip_id`.
  along a trip (`trip_id`) going a direction (`direction_id`) along a route (`route_id`).  This is the actual time a vehicle arrived at or departed from a stop, as opposed to a prediction of when a vehicle will arrive at or depart from a stop (`Model.Prediction.t`) or the scheduled time of arrival or departure (`Model.Schedule.t`).

  For the predicted times, see `Model.Prediction.t`.
  For the scheduled times, see `Model.Schedule.t`.
  """

  use Recordable, [
    :id,
    :vehicle_id,
    :start_date,
    :trip_id,
    :direction_id,
    :route_id,
    :start_time,
    :revenue,
    :stop_id,
    :stop_sequence,
    :arrived,
    :departed
  ]

  @typedoc """
  * `:id` - Composite key: `{trip_id}-{route_id}-{vehicle_id}-{stop_sequence}`.
  * `:vehicle_id` - The vehicle serving this trip. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `VehiclePosition` `VehicleDescriptor` `id`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicledescriptor).
  * `:start_date` - The service date of the `trip_id`.
  * `:trip_id` - The trip the `stop_id` is on. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-tripdescriptor)
  * `:direction_id` - Which direction along `route_id` the `trip_id` is going.  See
      [GTFS `trips.txt` `direction_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt).
  * `:route_id` - The route `trip_id` is on doing in `direction_id`.  See
      [GTFS `trips.txt` `route_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
  * `start_time` - The time the `trip_id` was scheduled to start.
  * `:revenue` - Whether or not the stop event is for a revenue trip.
  * `:stop_id` - Stop associated with arrived/departed. See
      [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `stop_id`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:stop_sequence` - The sequence of the stop along the `trip_id`.  The stop sequence increases monotonically but values need not be consecutive.
      See [GTFS `stop_times.txt` `stop_sequence`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt).
  * `:arrived` - When the vehicle arrived at the stop as seconds since Unix epoch in timezone `America/New_York`. `nil` if the first stop (`stop_id`) on the `trip_id`.
  * `:departed` - When the vehicle arrived at the stop as seconds since Unix epoch in timezone `America/New_York`. `nil` if the last stop (`stop_id`) on the `trip_id`
  """
  @type t :: %__MODULE__{
          id: String.t(),
          vehicle_id: Model.Vehicle.id(),
          start_date: Date.t(),
          trip_id: Model.Trip.id(),
          direction_id: Model.Direction.id(),
          route_id: Model.Route.id(),
          start_time: String.t(),
          stop_id: Model.Stop.id(),
          stop_sequence: non_neg_integer,
          revenue: :REVENUE | :NON_REVENUE,
          arrived: DateTime.t() | nil,
          departed: DateTime.t() | nil
        }

  @spec trip_id(t) :: Model.Trip.id()
  def trip_id(%__MODULE__{trip_id: trip_id}), do: trip_id

  @spec vehicle_id(t) :: String.t()
  def vehicle_id(%__MODULE__{vehicle_id: vehicle_id}), do: vehicle_id
end
