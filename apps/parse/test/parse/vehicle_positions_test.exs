defmodule Parse.VehiclePositionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.VehiclePositions
  alias Parse.Realtime.VehiclePosition

  describe "parse_vehicle_update/1" do
    test "can parse an empty position" do
      vp = %VehiclePosition{}
      vehicle = parse_vehicle_update(vp)
      assert vehicle.updated_at
    end
  end
end
