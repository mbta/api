defmodule ApiWeb.OccupancyView do
  use ApiWeb.Web, :api_view

  attributes([:id, :status, :percentage])

  @spec id(Model.CommuterRailOccupancy.t()) :: String.t()
  def id(%{trip_name: trip_name}, _conn) do
    "occupancy-" <> trip_name
  end

  @spec status(Model.CommuterRailOccupancy.t()) :: String.t()
  def status(%{status: :many_seats_available}), do: "MANY_SEATS_AVAILABLE"
  def status(%{status: :few_seats_available}), do: "FEW_SEATS_AVAILABLE"
  def status(%{status: :full}), do: "FULL"
  def status(_), do: ""
end
