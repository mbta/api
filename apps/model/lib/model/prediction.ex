defmodule Model.Prediction do
  @moduledoc """
  The predicted `arrival_time` and `departure_time` to/from a stop (`stop_id`) at a given sequence (`stop_sequence`)
  along a trip (`trip_id`) going a direction (`direction_id`) along a route (`route_id`).

  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-tripdescriptor)
  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate)

  For the scheduled times, see `Model.Schedule.t`.
  """

  use Recordable, [
    :trip_id,
    :stop_id,
    :route_id,
    :vehicle_id,
    :direction_id,
    :route_pattern_id,
    :arrival_time,
    :arrival_uncertainty,
    :departure_time,
    :departure_uncertainty,
    :stop_sequence,
    :schedule_relationship,
    :status,
    :update_type,
    trip_match?: false,
    last_trip?: false,
    revenue: :REVENUE
  ]

  @typedoc """
  | Value          | Description |
  |----------------|-------------|
  | `:added`       | An extra trip that was added in addition to a running schedule, for example, to replace a broken vehicle or to respond to sudden passenger load. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `ADDED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
  | `:cancelled`   | A trip that existed in the schedule but was removed. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `CANCELED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
  | `:no_data`     | No data is given for this stop. It indicates that there is no realtime information available. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship` `NO_DATA`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship) |
  | `:skipped`     | The stop was originally scheduled, but was skipped. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship) |
  | `:unscheduled` | A trip that is running with no schedule associated to it. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `UNSCHEDULED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
  | `nil`          | Stop was scheduled.  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `SCHEDULED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |

  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1)
  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship)
  """
  @type schedule_relationship :: :added | :cancelled | :no_data | :skipped | :unscheduled | nil

  @typedoc """
  Uncertainty value for the arrival time prediction.
  Bus and Commuter Rail
  See [entities tripUpdate stop_time_updates arrival uncertainty](https://swiftly-inc.stoplight.io/docs/realtime-standalone/613d1d7f1eae3-gtfs-rt-trip-updates)
  | Value            | Description |
  |------------------|-------------|
  | < 300 or omitted |	Valid real-time prediction |
  | 300              |  Real-time prediction not available. This code is primarily used when a vehicle has not yet been assigned to the trip, (i.e. because the block has not started yet). It is a schedule-based prediction, but Swiftly adjusts the schedule-based prediction time using observed historical travel times to make predictions more accurate than the schedule |
  | 301              |	Valid real-time prediction, though the bus appears to be stalled or significantly delayed and predictions are not as accurate |
  | > 301            |	Likely invalid prediction, recommend not showing anything (and not showing scheduled time), very rare situation |

  Subway
  See [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `arrival`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  | Value  | Description |
  |--------|-------------|
  | 60   | A trip that has already started |
  | 120  | A terminal/reverse trip departure for a trip that has NOT started and a train is awaiting departure at the origin |
  | 360  | A terminal/reverse trip for a trip that has NOT started and a train is completing a previous trip |
  """
  @type uncertainty_values :: non_neg_integer | nil

  @typedoc """
  * `:arrival_time` - When the vehicle is now predicted to arrive. `nil` if the first stop (`stop_id`) on the the trip
      (`trip_id`). See
      [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `arrival`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:arrival_uncertainty` - Value representing the uncertainty of arrival prediction (`arrival_time`). See
      [entities tripUpdate stop_time_updates arrival uncertainty](https://swiftly-inc.stoplight.io/docs/realtime-standalone/613d1d7f1eae3-gtfs-rt-trip-updates)
      [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `arrival`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:departure_time` - When the vehicle is now predicted to depart. `nil` if the last stop (`stop_id`) on the trip
      (`trip_id`). See
      [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `departure`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:departure_uncertainty` - Value representing the uncertainty of departure prediction (`departure_time`). See
      [entities tripUpdate stop_time_updates departure uncertainty](https://swiftly-inc.stoplight.io/docs/realtime-standalone/613d1d7f1eae3-gtfs-rt-trip-updates)
      [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `departure`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:direction_id` - Which direction along `route_id` the `trip_id` is going.  See
      [GTFS `trips.txt` `direction_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt).
  * `:route_id` - The route `trip_id` is on doing in `direction_id`.  See
      [GTFS `trips.txt` `route_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
  * `:schedule_relationship` - How the predicted stop relates to the `Model.Schedule.t` stops.
      See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1).
      See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship).
  * `:status` - Description of change
  * `:stop_id` - Stop whose arrival/departure is being predicted. See
      [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `stop_id`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:stop_sequence` -  The sequence the `stop_id` is arrived at during the `trip_id`.  The stop sequence is
      monotonically increasing along the trip, but the `stop_sequence` along the `trip_id` are not necessarily
      consecutive.  See
      [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `stop_sequence`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
  * `:trip_id` - The trip the `stop_id` is on. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-tripdescriptor)
  * `:trip_match?` - a boolean indicating whether the prediction is for a trip in the GTFS file
  * `:last_trip?` - a boolean indicating whether the prediction is for the last trip in a given service day
  * `:revenue` - An indication of whether or not the prediction is for a revenue trip
  * `:update_type` - TODO
  """
  @type t :: %__MODULE__{
          arrival_time: DateTime.t() | nil,
          arrival_uncertainty: uncertainty_values,
          departure_time: DateTime.t() | nil,
          departure_uncertainty: uncertainty_values,
          direction_id: Model.Direction.id(),
          route_id: Model.Route.id(),
          route_pattern_id: Model.RoutePattern.id(),
          vehicle_id: Model.Vehicle.id() | nil,
          schedule_relationship: schedule_relationship,
          status: String.t() | nil,
          stop_id: Model.Stop.id(),
          stop_sequence: non_neg_integer | nil,
          trip_id: Model.Trip.id(),
          trip_match?: boolean,
          last_trip?: boolean,
          revenue: :REVENUE | :NON_REVENUE,
          update_type: :mid_trip | :at_terminal | :reverse_trip
        }

  @spec trip_id(t) :: Model.Trip.id()
  def trip_id(%__MODULE__{trip_id: trip_id}), do: trip_id
end
