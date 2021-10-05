defmodule State.CommuterRailOccupancy do
  require Logger

  def size do
    0
  end

  def new_state(state, _timeout) do
    Logger.info("State.Occupancy new_state #{inspect(state)}")
  end
end
