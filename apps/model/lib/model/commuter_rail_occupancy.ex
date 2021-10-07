defmodule Model.CommuterRailOccupancy do
  @moduledoc """
  An expected or predicted level of occupancy for a given commuter rail trip.
  Stores the data we receive from Keolis, indexed by train name.
  Naming inspired by [GTFS-Occupancies proposal](https://github.com/google/transit/pull/240).
  """

  use Recordable, [
    :trip_name,
    :status,
    :percentage
  ]

  @type status ::
          :many_seats_available
          | :few_seats_available
          | :full

  @type t :: %__MODULE__{
          trip_name: String.t(),
          status: status(),
          percentage: non_neg_integer()
        }
end
