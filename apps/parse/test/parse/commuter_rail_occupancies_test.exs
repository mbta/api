defmodule Parse.CommuterRailOccupanciesTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Parse.CommuterRailOccupancies
  alias Model.CommuterRailOccupancy

  describe "parse" do
    test "parses valid data, ignoring invalid records" do
      json = """
      {
        "data": [
          {
            "cTrainNo": "1234   ",
            "MedianDensity": 0.23456,
            "MedianDensityFlag": 1
          },
          {
            "cTrainNo": "456   ",
            "MedianDensity": 0.0547,
            "MedianDensityFlag": 0
          },
          {
            "cTrainNo": "Missing fields"
          },
          {
            "cTrainNo": "invalid density flag",
            "MedianDensity": 0.578,
            "MedianDensityFlag": 10
          },
          {
            "cTrainNo": "invalid density",
            "MedianDensity": null,
            "MedianDensityFlag": 0
          },
          {
            "cTrainNo": 9999,
            "MedianDensity": 0.1,
            "MedianDensityFlag": 0
          },
          {
            "cTrainNo": "789   ",
            "MedianDensity": 0.8888,
            "MedianDensityFlag": 2
          }
        ]
      }
      """

      log =
        capture_log(fn ->
          assert parse(json) === [
                   %CommuterRailOccupancy{
                     trip_name: "1234",
                     status: :few_seats_available,
                     percentage: 23
                   },
                   %CommuterRailOccupancy{
                     trip_name: "456",
                     status: :many_seats_available,
                     percentage: 5
                   },
                   %CommuterRailOccupancy{
                     trip_name: "789",
                     status: :full,
                     percentage: 89
                   }
                 ]
        end)

      assert log =~ "missing_fields"
      assert log =~ "unknown_density_flag"
      assert log =~ "bad_density"
      assert log =~ "bad_trip_name"
    end
  end

  test "handles invalid JSON" do
    log =
      capture_log(fn ->
        assert parse("{abc") == []
      end)

    assert log =~ "decode_error"
  end
end
