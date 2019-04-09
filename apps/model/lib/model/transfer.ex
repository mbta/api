defmodule Model.Transfer do
  @moduledoc """

  Transfer specifies additional rules and overrides for a transfer.  See
  [GTFS `transfers.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt)

  """

  use Recordable, [
    :from_stop_id,
    :to_stop_id,
    :transfer_type,
    :min_transfer_time,
    :min_walk_time,
    :min_wheelchair_time,
    :suggested_buffer_time,
    :wheelchair_transfer
  ]

  @typedoc """
  | Value        | Description |
  | ------------ | ----------- |
  | `0` or empty | Recommended transfer point between routes |
  | `1`          | Timed transfer point between two routes |
  | `2`          | Transfer requires a minimum amount of time between arrival and departure to ensure a connection |
  | `3`          | Transfers are not possible between routes at the location |

  See [GTFS `transfers.txt` `transfer_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt).
  """
  @type transfer_type :: 0..3

  @typedoc """
  `wheelchair_transfer` is included in some records.

  When the value is present, `1` indicates a transfer is wheelchair accessible, `2` indicates it is not.
  """
  @type wheelchair_transfer :: 1..2 | nil

  @typedoc """
  * `:from_stop_id` - stops.stop_id identifying the stop/station where a connection between routes begins.
  * `:to_stop_id` - stops.stop_id identifying the stop/station where a connection between routes ends.
  * `:transfer_type` - see [GTFS `transfers.txt` `transfer_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#transferstxt).
  * `:min_transfer_time` - the sum of `min_walk_time` and `suggested_buffer_time`. see [`transfers.txt` `min_transfer_time`] (https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:min_walk_time` - minimum time required to travel by foot from `from_stop_id` to `to_stop_id`. see [`transfers.txt` `min_walk_time`] (https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:min_wheelchair_time` - minimum time required to travel by wheelchair from `from_stop_id` to `to_stop_id`. see [`transfers.txt` `min_wheelchair_time`] (https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:suggested_buffer_time` - recommended buffer time to allow to make a successful transfer between two services. see [`transfers.txt` `suggested_buffer_time`] (https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  * `:wheelchair_transfer` - see [`transfers.txt` `wheelchair_transfer`] (https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#transferstxt)
  """
  @type t :: %__MODULE__{
          from_stop_id: String.t(),
          to_stop_id: String.t(),
          transfer_type: transfer_type,
          min_transfer_time: non_neg_integer | nil,
          min_walk_time: non_neg_integer | nil,
          min_wheelchair_time: non_neg_integer | nil,
          suggested_buffer_time: non_neg_integer | nil,
          wheelchair_transfer: wheelchair_transfer
        }
end
