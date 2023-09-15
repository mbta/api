defmodule Parse.VehiclePositionsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.VehiclePositions
  alias Parse.Realtime.VehiclePosition

  @vehicle %{
    "id" => "y1796",
    "vehicle" => %{
      "current_status" => "IN_TRANSIT_TO",
      "occupancy_status" => "FULL",
      "current_stop_sequence" => 19,
      "multi_carriage_details" => [
        %{
          "label" => "some-carriage",
          "occupancy_status" => "MANY_SEATS_AVAILABLE",
          "occupancy_percentage" => 80,
          "carriage_sequence" => 1
        }
      ],
      "position" => %{
        "bearing" => 45,
        "latitude" => 42.342471209,
        "longitude" => -71.12175583
      },
      "stop_id" => "1308",
      "timestamp" => 1_568_143_091,
      "trip" => %{
        "direction_id" => 1,
        "route_id" => "66",
        "schedule_relationship" => "SCHEDULED",
        "start_date" => "20190910",
        "trip_id" => "41893421"
      },
      "vehicle" => %{
        "id" => "y1796",
        "label" => "1796"
      }
    }
  }

  describe "parse/1" do
    test "can parse JSON" do
      body = Jason.encode!(%{entity: [@vehicle]})

      expected = [
        %Model.Vehicle{
          bearing: 45,
          current_status: :in_transit_to,
          occupancy_status: :full,
          current_stop_sequence: 19,
          carriages: [
            %Model.Vehicle.Carriage{
              label: "some-carriage",
              carriage_sequence: 1,
              occupancy_status: :many_seats_available,
              occupancy_percentage: 80
            }
          ],
          direction_id: 1,
          id: "y1796",
          label: "1796",
          latitude: 42.342471209,
          longitude: -71.12175583,
          route_id: "66",
          speed: nil,
          stop_id: "1308",
          trip_id: "41893421",
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"])
        }
      ]

      actual = parse(body)
      assert actual == expected
    end

    test "can parse JSON with nil occupancy_status" do
      vehicle = %{@vehicle | "vehicle" => %{@vehicle["vehicle"] | "occupancy_status" => nil}}
      body = Jason.encode!(%{entity: [vehicle]})

      expected = [
        %Model.Vehicle{
          bearing: 45,
          current_status: :in_transit_to,
          occupancy_status: nil,
          current_stop_sequence: 19,
          carriages: [
            %Model.Vehicle.Carriage{
              label: "some-carriage",
              carriage_sequence: 1,
              occupancy_status: :many_seats_available,
              occupancy_percentage: 80
            }
          ],
          direction_id: 1,
          id: "y1796",
          label: "1796",
          latitude: 42.342471209,
          longitude: -71.12175583,
          route_id: "66",
          speed: nil,
          stop_id: "1308",
          trip_id: "41893421",
          updated_at: Parse.Timezone.unix_to_local(@vehicle["vehicle"]["timestamp"])
        }
      ]

      actual = parse(body)
      assert actual == expected
    end

    test "can parse gzip-encoded JSON" do
      body = :zlib.gzip(Jason.encode!(%{entity: [@vehicle]}))
      actual = parse(body)
      assert [_] = actual
    end
  end

  describe "parse_vehicle_update/1" do
    test "can parse an empty position" do
      vp = %VehiclePosition{}
      vehicle = parse_vehicle_update(vp)
      assert vehicle.updated_at
    end
  end
end
