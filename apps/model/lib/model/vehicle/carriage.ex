defmodule Model.Vehicle.Carriage do
  @moduledoc """
  A carriage (segment) of a vehicle (for example, an individual car on a train), used for
  more detailed occupancy information.
  """
  use Recordable, [
    :label,
    :carriage_sequence,
    :occupancy_status,
    :occupancy_percentage
  ]

  @typedoc """
  Carriage-level crowding details

  * `:label` -  Carriage-specific label, used as an identifier
  * `:carriage_sequence` - Provides a reliable order
  * `:occupancy_status` - The degree of passenger occupancy for the vehicle.
  * `:occupancy_percentage` - Percentage of vehicle occupied, calculated via weight average
  """
  @type t :: %__MODULE__{
          label: String.t() | nil,
          carriage_sequence: String.t() | nil,
          occupancy_status: String.t() | nil,
          occupancy_percentage: String.t() | nil
        }
end
