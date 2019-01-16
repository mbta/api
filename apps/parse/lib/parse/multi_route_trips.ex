defmodule Parse.MultiRouteTrips do
  @moduledoc """
  Parses `multi_route_trips.txt` CSV from GTFS zip

      added_route_id,trip_id
      12,hybrid
      34,hybrid
      CR-Lowell,"gene's"

  """

  use Parse.Simple
  alias Model.MultiRouteTrip

  @doc """
  Parses (non-header) row of `multi_route_trips.txt`
  """
  @spec parse_row(row :: %{optional(String.t()) => String.t()}) :: MultiRouteTrip.t()
  def parse_row(row) do
    %MultiRouteTrip{
      added_route_id: copy(row["added_route_id"]),
      trip_id: copy(row["trip_id"])
    }
  end
end
