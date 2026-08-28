defmodule Model.Transfer do
  @moduledoc """
  Transfer specifies additional rules and overrides for a transfer between trips, routes, and/or stops.
  [GTFS `transfers.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  """

  use Recordable, [
    :from_stop_id,
    :to_stop_id,
    :min_transfer_time,
    :min_walk_time,
    :min_wheelchair_time,
    :suggested_buffer_time,
    :from_trip_id,
    :to_trip_id,
    transfer_type: 0,
    wheelchair_transfer: 0
  ]

  @typedoc """
  Amount of time, in seconds, that must be available to permit a transfer between routes at the specified stops.
  The `min_transfer_time` should be sufficient to permit a typical rider to move between the two stops, including buffer time to allow for schedule variance on each route.
  """
  @type min_transfer_time :: non_neg_integer()

  @typedoc """
  | Value      | Description |
  |------------|-------------|
  | 0 or empty | Recommended between routes |
  | 1          | Timed between two routes |
  | 2          | Requires a minimum amount of time to ensure connection |
  | 3          | Transfers not possible between routes at the location |
  | 4          | In-seat transfer between sequential trips |
  | 5          | In-seat transfers not allowed between sequential trips |

  See [GTFS `transfers.txt` `transfer_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  """
  @type transfer_type :: 0..5

  @typedoc """
  | Value      | Description |
  |------------|-------------|
  | 0 or empty | No accessibility information for the transfer |
  | 1          | Transfer is wheelchair accessible |
  | 2          | Not accessible to persons in wheelchairs |
  """
  @type wheelchair_transfer_type :: 0..2

  @typedoc """
  * `:from_stop_id` - The `Model.Stop.id` of the `Model.Stop.t` where a connection between routes begins. See [GTFS `transfers.txt` `from_stop_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  * `:to_stop_id` - The `Model.Stop.id` of the `Model.Stop.t` where a connection between routes ends. See [GTFS `transfers.txt` `to_stop_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  * `:min_transfer_time` - As specified in the GTFS standard, this field is the sum of `min_walk_time` and `suggested_buffer_time`. See [MBTA GTFS `transfers.txt` `min_transfer_time`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:min_walk_time` - Experimental. Minimum time required to travel by foot from `from_stop_id` to `to_stop_id`. See [MBTA GTFS `transfers.txt` `min_walk_time`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:min_wheelchair_time` - Experimental. Minimum time required to travel by wheelchair `from_stop_id` to `to_stop_id`. If the transfer is not wheelchair accessible, this field will be blank. See [MBTA GTFS `transfers.txt` `min_wheelchair_time`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:suggested_buffer_time` - Experimental. Recommended buffer time to allow to make a successful transfer between two services. This is also partly based on the significance of missing the transfer (due to service frequency). See [MBTA GTFS `transfers.txt` `suggested_buffer_time`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:wheelchair_transfer` - Experimental. Identifies whether a transfer is accessible to customers using a wheelchair. See [MBTA GTFS `transfers.txt` `wheelchair_transfer`](https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:from_trip_id` - If present, specifies that the transfer is exclusively valid from this trip to the trip specified in `to_trip_id`. See [GTFS `transfers.txt` `from_trip_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  * `:to_trip_id` - If present, specifies that the transfer is exclusively valid to this trip from the trip specified in `from_trip_id`. See [GTFS `transfers.txt` `to_trip_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  * `:transfer_type` - Indicates the type of connection for the specified (`from_stop_id`, `to_stop_id`) pair. See [GTFS `transfers.txt` `transfer_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)
  """
  @type t :: %__MODULE__{
          from_stop_id: Model.Stop.id(),
          to_stop_id: Model.Stop.id(),
          min_transfer_time: min_transfer_time() | nil,
          min_walk_time: non_neg_integer | nil,
          min_wheelchair_time: non_neg_integer | nil,
          suggested_buffer_time: non_neg_integer | nil,
          wheelchair_transfer: wheelchair_transfer_type,
          from_trip_id: Model.Trip.id() | nil,
          to_trip_id: Model.Trip.id() | nil,
          transfer_type: transfer_type
        }
end
