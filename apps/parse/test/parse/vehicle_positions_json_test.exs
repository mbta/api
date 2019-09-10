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
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"])
        }
      ]

      actual = parse(body)
      assert actual == expected
    end
  end

  describe "parse_entity/1" do
    test "returns a list of predictions" do
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
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"])
        }
      ]

      actual = parse_entity(@vehicle)
      assert actual == expected
    end

    test "handles vehicles with missing attributes" do
      assert [%Model.Vehicle{id: "y0487"}] = parse_entity(@vehicle2)
    end
  end
end
