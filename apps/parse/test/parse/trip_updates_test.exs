defmodule Parse.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.TripUpdates
  alias Parse.Realtime.TripUpdate.StopTimeEvent

  describe "parse/1" do
    test "can parse an Enhanced JSON file" do
      trip = %{
        "trip_id" => "CR-Weekday-Spring-17-205",
        "start_date" => "2017-08-09",
        "schedule_relationship" => "SCHEDULED",
        "route_id" => "CR-Haverhill",
        "direction_id" => 0
      }

      update = %{
        "stop_id" => "place-north",
        "stop_sequence" => 6,
        "departure" => %{
          "time" => 1_502_290_500
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

  describe "parse_trip_update/1" do
    test "parses a vehicle ID if present" do
      update = %{
        trip: %{
          trip_id: "trip",
          route_id: "route",
          direction_id: 0,
          schedule_relationship: :SCHEDULED
        },
        stop_time_update: [
          %{
            stop_id: "stop",
            stop_sequence: 5,
            arrival: %{
              time: 1
            },
            departure: nil,
            schedule_relationship: :SCHEDULED
          }
        ],
        vehicle: %{
          id: "vehicle"
        }
      }

      [actual] = parse_trip_update(update)

      assert %Model.Prediction{
               trip_id: "trip",
               route_id: "route",
               stop_id: "stop",
               vehicle_id: "vehicle",
               stop_sequence: 5,
               arrival_time: %DateTime{}
             } = actual
    end

    test "does not require a vehicle ID" do
      update = %{
        trip: %{
          trip_id: "trip",
          route_id: "route",
          direction_id: 0,
          schedule_relationship: :SCHEDULED
        },
        stop_time_update: [
          %{
            stop_id: "stop",
            stop_sequence: 5,
            arrival: %{
              time: 1
            },
            departure: nil,
            schedule_relationship: :SCHEDULED
          }
        ],
        vehicle: nil
      }

      [actual] = parse_trip_update(update)

      assert %Model.Prediction{
               vehicle_id: nil
             } = actual
    end
  end

  describe "parse_stop_time_event/1" do
    test "returns a local datetime if the time is present" do
      ndt = ~N[2017-01-01T00:00:00]
      expected = Timex.to_datetime(ndt, "America/New_York")
      event = %StopTimeEvent{time: DateTime.to_unix(expected)}
      actual = parse_stop_time_event(event)
      assert expected == actual
    end

    test "returns nil in other cases" do
      assert parse_stop_time_event(%StopTimeEvent{time: nil}) == nil
      assert parse_stop_time_event(%StopTimeEvent{time: 0}) == nil
      assert parse_stop_time_event(nil) == nil
    end
  end
end
