defmodule Parse.Directions do
  @moduledoc """
  Parser for GTFS directions.txt
  """
  use Parse.Simple
  defstruct [:route_id, :direction_id, :direction, :direction_destination]

  def parse_row(row) do
    %__MODULE__{
      route_id: copy(row["route_id"]),
      direction_id: copy(row["direction_id"]),
      direction: copy(row["direction"]),
      direction_destination: copy(row["direction_destination"])
    }
  end
end
