defmodule GreenLine.SegmentTest do
  use ExUnit.Case, async: true
  import GreenLine.Segment

  describe "by_latitude_longitude/3" do
    test "returns a segment given a latitude/longitude/bearing triple" do
      {latitude, longitude} = {42.3660888671875, -71.06298065185547}
      assert by_latitude_longitude(latitude, longitude, 230.0) == "N_Sta_Before_TurnbackEB"
      {latitude, longitude} = {42.359291076660156, -71.05951690673828}
      assert by_latitude_longitude(latitude, longitude, 215.0) == "Govt_Ctr_ParkWB"
      {latitude, longitude} = {42.36238098144531, -71.05803680419922}
      assert by_latitude_longitude(latitude, longitude, 175.0) == "HaymarketWB"
      {latitude, longitude} = {42.359859466552734, -71.05890655517578}
      assert by_latitude_longitude(latitude, longitude, 35.0) == "Govt_Ctr_Haymarket_or_LoopEB"
    end

    test "returns nil if no segment matches" do
      assert by_latitude_longitude(0.0, 0.0, 0.0) == nil
    end
  end
end
