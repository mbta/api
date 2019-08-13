defmodule State.PredictionTest do
  @moduledoc false
  use ExUnit.Case
  import State.Prediction

  @prediction %Model.Prediction{
    trip_id: "trip",
    route_id: "route",
    stop_id: "stop"
  }

  @prediction2 %Model.Prediction{
    trip_id: "trip2",
    route_id: "route2",
    stop_id: "stop"
  }

  setup do
    State.Trip.new_state([])
    State.Stop.new_state([])
    new_state([@prediction])
  end

  test "can query by trip id, stop id, route id" do
    assert by_trip_id("trip") == [@prediction]
    assert by_stop_id("stop") == [@prediction]
    assert by_route_id("route") == [@prediction]
    assert by_trip_id("") == []
    assert by_stop_id("") == []
    assert by_route_id("") == []

    {data, _} = by_trip_id("trip", limit: 1)
    assert data == [@prediction]
  end

  test "can query by stop and route together" do
    assert by_stop_route("stop", "route") == [@prediction]
    assert by_stop_route("stop", "") == []
    assert by_stop_route("", "route") == []
    assert by_stop_route("", "") == []
  end

  test "if the prediction is for a trip with alternate routes, makes predictions for that route as well" do
    State.Trip.new_state([
      %Model.Trip{id: "trip", route_id: "route", alternate_route: false},
      %Model.Trip{id: "trip", route_id: "alternate", alternate_route: true}
    ])

    new_state([@prediction])

    assert by_route_id("alternate") == [%{@prediction | route_id: "alternate"}]
  end

  describe "filter_by_route_type/2" do
    test "returns all predictions if no filters set" do
      new_state([@prediction, @prediction2])
      by_stops = by_stop_id("stop")
      assert filter_by_route_type(by_stops, nil) == [@prediction, @prediction2]
      assert filter_by_route_type(by_stops, []) == [@prediction, @prediction2]
    end

    test "filters by route_type" do
      new_state([@prediction, @prediction2])
      by_stops = by_stop_id("stop")

      route1 = %Model.Route{id: "route", type: 0}
      route2 = %Model.Route{id: "route2", type: 1}
      State.Route.new_state([route1, route2])

      assert filter_by_route_type(by_stops, [0]) == [@prediction]
      assert filter_by_route_type(by_stops, [1]) == [@prediction2]
      assert filter_by_route_type(by_stops, [0, 1]) == [@prediction, @prediction2]
      assert filter_by_route_type(by_stops, [2]) == []
    end
  end

  describe "pre_insert_hook/1" do
    test "takes direction id from trip if missing" do
      State.Trip.new_state([
        %Model.Trip{id: "trip_with_direction", direction_id: 1}
      ])

      prediction = %Model.Prediction{
        trip_id: "trip_with_direction"
      }

      assert [%{direction_id: 1}] = pre_insert_hook(prediction)
    end
  end

  describe "prediction_for/2" do
    @today Date.utc_today()
    @datetime Timex.to_datetime(@today, "America/New_York")
    @schedule %Model.Schedule{
      route_id: "route",
      trip_id: "trip",
      stop_id: "stop",
      direction_id: 1,
      # 12:30pm
      arrival_time: 45_000,
      departure_time: 45_100,
      drop_off_type: 1,
      pickup_type: 1,
      timepoint?: false,
      service_id: "service",
      stop_sequence: 2,
      position: :first
    }
    @service %Model.Service{
      id: "service",
      start_date: @today,
      end_date: @today,
      added_dates: [@today]
    }
    @other_service %Model.Service{
      id: "other_service",
      start_date: @today,
      end_date: @today,
      added_dates: [@today]
    }
    @predictions [
      %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
        departure_time: Timex.set(@datetime, hour: 12, minute: 30)
      },
      %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 1,
        direction_id: 1,
        arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
        departure_time: Timex.set(@datetime, hour: 12, minute: 30)
      },
      %Model.Prediction{
        route_id: "route",
        trip_id: "other_trip",
        stop_id: "stop",
        stop_sequence: 2,
        direction_id: 0,
        arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
        departure_time: Timex.set(@datetime, hour: 12, minute: 30)
      },
      %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "other_stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
        departure_time: Timex.set(@datetime, hour: 12, minute: 30)
      }
    ]

    setup do
      State.Stop.new_state([])
      State.Service.new_state([@service, @other_service])
      State.ServiceByDate.update!()
      State.Schedule.new_state([@schedule])
      State.Prediction.new_state(@predictions)
    end

    test "returns all predictions that have the same {trip, stop, stop_sequence}" do
      prediction = prediction_for(@schedule, @today)

      assert prediction.trip_id == @schedule.trip_id
      assert prediction.stop_id == @schedule.stop_id
      assert prediction.stop_sequence == @schedule.stop_sequence
    end

    test "returns a prediction if it's been assigned to a different track" do
      stops = [
        %Model.Stop{
          id: "stop-01",
          parent_station: "parent",
          platform_code: "1",
          location_type: 0
        },
        %Model.Stop{id: "stop", parent_station: "parent", location_type: 0},
        %Model.Stop{id: "parent", location_type: 1}
      ]

      State.Stop.new_state(stops)
      prediction = List.first(@predictions)
      prediction = %{prediction | stop_id: "stop-01"}
      State.Prediction.new_state([prediction])

      assert prediction_for(@schedule, @today) == prediction
    end

    test "does not return prediction if the arrival and departure dates are
    different than the provided date" do
      refute prediction_for(
               @schedule,
               Timex.add(@today, Timex.Duration.from_days(1))
             )
    end

    test "returns predictions that cross midnight but are on the same service date" do
      schedule = %Model.Schedule{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        direction_id: 1,
        # 11:59:50pm
        arrival_time: 86_390,
        # 11:59:50pm
        departure_time: 86_390,
        drop_off_type: 1,
        pickup_type: 1,
        timepoint?: false,
        service_id: "service",
        stop_sequence: 2,
        position: :first
      }

      delayed_time =
        @datetime
        |> Timex.add(Timex.Duration.from_days(1))
        |> Timex.set(hour: 0, minute: 5)

      prediction = %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: delayed_time,
        departure_time: delayed_time
      }

      State.Schedule.new_state([schedule])
      State.Prediction.new_state([prediction])

      assert %Model.Prediction{} = prediction_for(schedule, @today)
    end
  end

  describe "prediction_for_many/2" do
    @today Date.utc_today()
    @datetime Timex.to_datetime(@today, "America/New_York")
    @service %Model.Service{
      id: "service",
      start_date: @today,
      end_date: @today,
      added_dates: [@today]
    }
    @other_service %Model.Service{
      id: "other_service",
      start_date: @today,
      end_date: @today,
      added_dates: [@today]
    }
    @schedules [
      %Model.Schedule{
        route_id: "route",
        trip_id: "trip1",
        stop_id: "stop",
        direction_id: 1,
        # 12:30pm
        arrival_time: 45_000,
        departure_time: 45_100,
        drop_off_type: 1,
        pickup_type: 1,
        timepoint?: false,
        service_id: "service",
        stop_sequence: 1,
        position: :first
      },
      %Model.Schedule{
        route_id: "route",
        trip_id: "trip2",
        stop_id: "stop",
        direction_id: 1,
        # 12:30pm
        arrival_time: 45_000,
        departure_time: 45_100,
        drop_off_type: 1,
        pickup_type: 1,
        timepoint?: false,
        service_id: "service",
        stop_sequence: 2,
        position: :first
      }
    ]

    @prediction1 %Model.Prediction{
      route_id: "route",
      trip_id: "trip1",
      stop_id: "stop",
      stop_sequence: 1,
      direction_id: 1,
      arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
      departure_time: Timex.set(@datetime, hour: 12, minute: 30)
    }
    @prediction2 %Model.Prediction{
      route_id: "route",
      trip_id: "trip2",
      stop_id: "stop",
      stop_sequence: 2,
      direction_id: 1,
      arrival_time: Timex.set(@datetime, hour: 12, minute: 30),
      departure_time: Timex.set(@datetime, hour: 12, minute: 30)
    }

    setup do
      State.Service.new_state([@service, @other_service])
      State.ServiceByDate.update!()
    end

    test "returns predictions for multiple schedules" do
      State.Prediction.new_state([@prediction1, @prediction2])

      assert prediction_for_many(@schedules, @today) == %{
               {"trip1", 1} => @prediction1,
               {"trip2", 2} => @prediction2
             }
    end
  end
end
