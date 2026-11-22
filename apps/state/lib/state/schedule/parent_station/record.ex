defmodule State.Schedule.ParentStation.Record do
  @moduledoc """
  A `Model.Schedule.t` at a stop inside a parent station, stored under that
  station. `stop_sequence` and `position` are copied from the schedule so they
  can be matched on.
  """

  use Recordable, [:trip_id, :parent_station, :stop_sequence, :position, :schedule]

  @type t :: %__MODULE__{
          trip_id: Model.Trip.id(),
          parent_station: Model.Stop.id(),
          stop_sequence: Model.Schedule.stop_sequence(),
          position: :first | :last | nil,
          schedule: Model.Schedule.t()
        }
end
