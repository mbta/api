defmodule Parse.VehiclePositionsJsonTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.VehiclePositionsJson

  @vehicle %{
    "id" => "y0487",
    "vehicle" => %{
      "current_status" => "IN_TRANSIT_TO",
      "current_stop_sequence" => 1,
      "position" => %{
        "bearing" => 225,
        "latitude" => 42.3378024,
        "longitude" => -71.1028282
      },
      "stop_id" => "11802",
      "timestamp" => 1_567_709_072,
      "trip" => %{
        "direction_id" => 1,
        "route_id" => "708",
        "schedule_relationship" => "SCHEDULED",
        "start_date" => "20190905",
        "trip_id" => "41820413"
      },
      "vehicle" => %{"id" => "y0487", "label" => "0487"}
    }
  }

  @vehicle2 %{
    "id" => "y0487",
    "vehicle" => %{
      "position" => %{},
      "trip" => %{},
      "vehicle" => %{"id" => "y0487"}
    }
  }

  describe "parse/1" do
    test "returns a list of vehicles" do
      body = Jason.encode!(%{entity: [@vehicle]})

      expected = [
        %Model.Vehicle{
          bearing: 225,
          current_status: :in_transit_to,
          current_stop_sequence: 1,
          direction_id: 1,
          id: "y0487",
          label: "0487",
          latitude: 42.3378024,
          longitude: -71.1028282,
          route_id: "708",
          speed: nil,
          stop_id: "11802",
          trip_id: "41820413",
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"]),
          consist: nil
        }
      ]

      actual = parse(body)
      assert actual == expected
    end
  end

  describe "parse_entity/1" do
    test "returns a list of vehicles" do
      expected = [
        %Model.Vehicle{
          bearing: 225,
          current_status: :in_transit_to,
          current_stop_sequence: 1,
          direction_id: 1,
          id: "y0487",
          label: "0487",
          latitude: 42.3378024,
          longitude: -71.1028282,
          route_id: "708",
          speed: nil,
          stop_id: "11802",
          trip_id: "41820413",
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"]),
          consist: nil
        }
      ]

      actual = parse_entity(@vehicle)
      assert actual == expected
    end

    test "handles vehicles with missing attributes" do
      assert [%Model.Vehicle{id: "y0487"}] = parse_entity(@vehicle2)
    end

    test "handles a vehicle with consist present" do
      entity = %{
        "id" => "R-5460560B",
        "vehicle" => %{
          "current_status" => "INCOMING_AT",
          "current_stop_sequence" => 30,
          "position" => %{
            "bearing" => 185,
            "latitude" => 42.3796,
            "longitude" => -71.1203
          },
          "stop_id" => "70067",
          "timestamp" => 1_570_539_011,
          "trip" => %{
            "direction_id" => 0,
            "route_id" => "Red",
            "schedule_relationship" => "SCHEDULED",
            "start_date" => "20191008",
            "trip_id" => "41527237"
          },
          "vehicle" => %{
            "consist" => [
              %{"label" => "1877"},
              %{"label" => "1876"},
              %{"label" => "1854"},
              %{"label" => "1855"},
              %{"label" => "1833"},
              %{"label" => "1832"}
            ],
            "id" => "R-5460560B",
            "label" => "1877"
          }
        }
      }

      [%{consist: consist}] = parse_entity(entity)
      assert consist == MapSet.new(["1832", "1833", "1854", "1855", "1876", "1877"])
    end
  end
end
