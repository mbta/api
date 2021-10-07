defmodule State.CommuterRailOccupancy do
  @moduledoc """
  Manages the expected level of crowding of Commuter Rail trains, provided
  by the Keolis firebase feed.
  """

  use State.Server,
    indices: [:trip_name],
    parser: Parse.CommuterRailOccupancies,
    recordable: Model.CommuterRailOccupancy
end
