defmodule State.Facility.Property do
  @moduledoc """
  Manages the list of elevators/escalators.
  """
  use State.Server,
    fetched_filename: "facilities_properties.txt",
    recordable: Model.Facility.Property,
    indicies: [:facility_id, :name],
    parser: Parse.Facility.Property
end
