defmodule Parse.CommuterRailDepartures.JSONTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.CommuterRailDepartures.JSON

  @trip %{
    "trip_id" => "CR-Weekday-Spring-17-205",
    "start_date" => "2017-08-09",
    "schedule_relationship" => "SCHEDULED",
    "route_id" => "CR-Haverhill",
    "direction_id" => 0
  }
  @update %{
    "stop_id" => "place-north",
    "stop_sequence" => 6,
    "departure" => %{
      "time" => 1_502_290_500
    }
  }

  describe "parse/1" do
    test "returns a list of predictions" do
      body =
        Jason.encode!(%{entity: [%{trip_update: %{trip: @trip, stop_time_update: [@update]}}]})

      expected = [prediction(@update, @trip)]
      actual = parse(body)
      assert actual == expected
    end
  end

  describe "parse_entity/1" do
    test "returns a list of predictions" do
      entity = %{
        "trip_update" => %{
          "trip" => @trip,
          "stop_time_update" => [@update]
        }
      }

      expected = [prediction(@update, @trip)]
      actual = parse_entity(entity)
      assert actual == expected
    end

    test "ignores trips without stop_time_updates" do
      entity = %{
        "trip_update" => %{
          "trip" => @trip
        }
      }

      expected = []
      actual = parse_entity(entity)
      assert actual == expected
    end
  end

  describe "prediction/2" do
    test "returns a %Model.Prediction{}" do
      expected = %Model.Prediction{
        trip_id: @trip["trip_id"],
        stop_id: @update["stop_id"],
        route_id: @trip["route_id"],
        direction_id: @trip["direction_id"],
        arrival_time: nil,
        departure_time: Parse.Timezone.unix_to_local(@update["departure"]["time"]),
        stop_sequence: @update["stop_sequence"],
        schedule_relationship: nil,
        status: nil
      }

      actual = prediction(@update, @trip)
      assert actual == expected
    end

    test "keeps the status the same" do
      update = put_in(@update["boarding_status"], "Stopped 1_0 miles away")
      actual = prediction(update, @trip)
      assert actual.status == "Stopped 1_0 miles away"
    end

    test "handles other kinds of relationship" do
      update = put_in(@update["schedule_relationship"], "SKIPPED")
      actual = prediction(update, @trip)
      assert %Model.Prediction{schedule_relationship: :skipped} = actual

      trip = put_in(@trip["schedule_relationship"], "ADDED")
      actual = prediction(@update, trip)
      assert %Model.Prediction{schedule_relationship: :added} = actual

      # prefers the relationship from the update
      actual = prediction(update, @trip)
      assert %Model.Prediction{schedule_relationship: :skipped} = actual
    end

    test "handles various cases of missing time" do
      for departure <- [
            nil,
            %{},
            %{"time" => nil}
          ] do
        update = put_in(@update["departure"], departure)
        actual = prediction(update, @trip)
        assert %Model.Prediction{departure_time: nil} = actual
      end
    end
  end
end
