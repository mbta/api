defmodule State.Facility.Parking do
  @moduledoc """
  Maintains the current state of the parking information (coming from IBM).
  """
  use State.Server,
    recordable: Model.Facility.Property,
    indicies: [:facility_id, :name],
    parser: Parse.Facility.Parking
end
