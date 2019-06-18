defmodule Model.Schedule do
  @moduledoc """
  The arrival drop off (`drop_off_type`) time (`arrival_time`) and departure pick up (`pickup_type`) time
  (`departure_time`) to/from a stop (`stop_id`) at a given sequence (`stop_sequence`) along a trip (`trip_id`) going in
  a direction (`direction_id`) along a route (`route_id`) when the trip is following a service (`service_id`) to
  determine when it is active.

  See [GTFS `stop_times.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)

  For predictions of the actual arrival/departure time, see `Model.Prediction.t`.
  """

  use Recordable, [
    :trip_id,
    :stop_id,
    :arrival_time,
    :departure_time,
    :stop_sequence,
    :pickup_type,
    :drop_off_type,
    :position,
    :route_id,
    :direction_id,
    :service_id,
    :timepoint?,
    :stop_n_trip
  ]

  @typedoc """
  | Value | Description                 |
  |-------|-----------------------------|
  | `0`   | Regularly scheduled         |
  | `1`   | Not available               |
  | `2`   | Must phone agency           |
  | `3`   | Must coordinate with driver |

  See [GTFS `stop_times.txt` `drop_off_type` and `pickup_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  """
  @type pickup_drop_off_type :: 0..3

  @typedoc """
  The number of seconds past midnight
  """
  @type seconds_past_midnight :: non_neg_integer

  @typedoc """
  * `true` - `arrival_time` and `departure_time` are exact
  * `false` - `arrival_time` and `departure_time` are approximate or interpolated
  """
  @type timepoint :: boolean

  @typedoc """
  * `:arrival_time` - When the vehicle arrives at `stop_id`. `nil` if the first stop (`stop_id`) on the trip
      (`trip_id`).  See
      [GTFS `stop_times.txt` `arrival_time`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:departure_time` - When the vehicle arrives at `stop_id`. `nil` if the last stop (`stop_id`) on the trip
      (`trip_id`). See
      [GTFS `stop_times.txt` `departure_time`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:direction_id` - Which direction along `route_id` the `trip_id` is going.  See
      [GTFS `trips.txt` `direction_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
  * `:drop_off_type` - How the vehicle arrives at `stop_id`.  See
      [GTFS `stop_times.txt` `drop_off_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:pickup_type` - How the vehicle departs from `stop_id`.  See
      [GTFS `stop_times.txt` `pickup_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:position` - Marks the first and last stop on the trip, so that the range of `stop_sequence` does not need to be
      known or calculated.
  * `:route_id` - The route `trip_id` is on doing in `direction_id`.  See
      [GTFS `trips.txt` `route_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
  * `:service_id` - The service that `trip_id` is following to determine when it is active.  See
      [GTFS `trips.txt` `service_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxxt)
  * `:stop_id` - The stop being arrived at and departed from.  See
      [GTFS `stop_times.txt` `stop_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:stop_sequence` - The sequence the `stop_id` is arrived at during the `trip_id`.  The stop sequence is
      monotonically increasing along the trip, but the `stop_sequence` along the `trip_id` are not necessarily
      consecutive.  See
      [GTFS `stop_times.txt` `stop_sequence`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:timepoint?` - `true` if `arrival_time` and `departure_time` are exact; otherwise, `false`. See
      [GTFS `stop_times.txt` `timepoint`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  * `:trip_id` - The trip on which `stop_id` occurs in `stop_sequence`. See
      [GTFS `stop_times.txt` `trip_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
  """
  @type t :: %__MODULE__{
          arrival_time: seconds_past_midnight | nil,
          departure_time: seconds_past_midnight | nil,
          direction_id: Model.Direction.id(),
          drop_off_type: pickup_drop_off_type,
          pickup_type: pickup_drop_off_type,
          position: :first | :last | nil,
          route_id: Model.Route.id(),
          service_id: Model.Service.id(),
          stop_id: Model.Stop.id(),
          stop_sequence: non_neg_integer,
          timepoint?: timepoint,
          trip_id: Model.Trip.id(),
          stop_n_trip: {Model.Stop.id(), Model.Trip.id()}
        }

  @doc """
  The arrival time or departure time of the schedule.
  """
  @spec time(t) :: seconds_past_midnight
  def time(%__MODULE__{arrival_time: time}) when not is_nil(time) do
    time
  end

  def time(%__MODULE__{departure_time: time}) when not is_nil(time) do
    time
  end
end
