defmodule Parse.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.GtfsRt.TripUpdates

  describe "parse/1" do
    test "can parse an Enhanced JSON file" do
      trip = %{
        "trip_id" => "CR-Weekday-Spring-17-205",
        "start_date" => "2017-08-09",
        "schedule_relationship" => "SCHEDULED",
        "route_id" => "CR-Haverhill",
        "direction_id" => 0,
        "revenue" => true,
        "last_trip" => false
      }

      update = %{
        "stop_id" => "place-north",
        "stop_sequence" => 6,
        "arrival" => %{
          "time" => 1_502_290_000
        },
        "departure" => %{
          "time" => 1_502_290_500,
          "uncertainty" => 60
        }
      }

      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: trip,
                stop_time_update: [update]
              }
            }
          ]
        })

      assert [%Model.Prediction{}] = parse(body)
    end
  end
end
