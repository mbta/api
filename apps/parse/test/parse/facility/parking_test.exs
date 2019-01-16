defmodule Parse.Facility.ParkingTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.Facility.Parking

  describe "parse/1" do
    test "can parse a basic JSON binary" do
      binary = ~s(
      {
        "counts": [
          {
            "garageName": "MBTA Route 128",
            "freeSpace": "1020",
            "capacity": "2430",
            "displayStatus": "FULL",
            "dateTime": "05/21/18 16:19:59",
            "garageId": "0"
          }
        ]
      }
      )
      expected_updated_at = Parse.Timezone.unix_to_local(1_526_933_999)

      properties =
        for property <- parse(binary), into: %{} do
          assert property.facility_id == "park-NEC-2173-garage"
          assert property.updated_at == expected_updated_at
          {property.name, property.value}
        end

      # number of spaces used = capacity - free space
      assert properties["utilization"] == 1410
      assert properties["capacity"] == 2430
      assert properties["status"] == "FULL"
    end

    test "treats a NULL display status as `nil`" do
      binary = ~s(
      {
        "counts": [
          {
            "garageName": "MBTA Route 128",
            "freeSpace": "1020",
            "capacity": "2430",
            "displayStatus": "NULL",
            "dateTime": "05/21/18 16:19:59",
            "garageId": "0"
          }
        ]
      }
      )

      properties =
        for property <- parse(binary), into: %{} do
          {property.name, property.value}
        end

      assert properties["status"] == nil
    end

    test "handles a integer freeSpace or capacity" do
      binary = ~s(
      {
        "counts": [
          {
            "garageName": "MBTA Route 128",
            "freeSpace": 1,
            "capacity": 5,
            "displayStatus": "NULL",
            "dateTime": "05/21/18 16:19:59",
            "garageId": "0"
          }
        ]
      }
      )

      properties =
        for property <- parse(binary), into: %{} do
          {property.name, property.value}
        end

      assert properties["capacity"] == 5
      assert properties["utilization"] == 4
    end

    test "ignores garages we don't know about" do
      binary = ~s(
      {
        "counts": [
          {
            "garageName": "unknown,
            "freeSpace": "1020",
            "capacity": "2430",
            "displayStatus": "NULL",
            "dateTime": "05/21/18 16:19:59",
            "garageId": "0"
          }
        ]
      }
      )

      assert parse(binary) == []
    end

    test "ignores invalid date times" do
      binary = ~s(
      {
        "counts": [
          {
            "garageName": "MBTA Route 128",
            "freeSpace": "1020",
            "capacity": "2430",
            "displayStatus": "NULL",
            "dateTime": "invalid",
            "garageId": "0"
          }
        ]
      }
      )
      assert parse(binary) == []
    end
  end
end
