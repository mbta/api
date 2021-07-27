defmodule State.ScheduleTest do
  use ExUnit.Case

  import Parse.Time, only: [service_date: 0]

  alias State.Schedule

  @today service_date()
  @route %Model.Route{id: "route"}
  @stop %Model.Stop{id: "stop"}
  @service %Model.Service{
    id: "service",
    valid_days: [],
    start_date: @today,
    end_date: Timex.shift(@today, days: 2),
    added_dates: [@today],
    removed_dates: []
  }
  @route_pattern %Model.RoutePattern{id: "route-_-1"}
  @trip %Model.Trip{
    id: "trip",
    route_id: "route",
    direction_id: 1,
    service_id: "service",
    route_pattern_id: "route-_-1"
  }
  @schedule %Model.Schedule{
    route_id: "route",
    trip_id: "trip",
    stop_id: "stop",
    direction_id: 1,
    # 12:30pm
    arrival_time: 45_000,
    service_id: "service",
    stop_sequence: 2,
    position: :first
  }

  setup do
    State.Route.new_state([@route])
    State.Stop.new_state([@stop])
    State.Trip.new_state([@trip])
    State.Service.new_state([@service])
    Schedule.new_state([@schedule])
    State.RoutePattern.new_state([@route_pattern])
    State.RoutesPatternsAtStop.update!()
  end

  test "init" do
    assert {:ok, %{data: _, last_updated: nil}, :hibernate} = State.Schedule.init([])
  end

  describe "filter_by/1" do
    test "returns [] when neither :routes, :trips, or :stops is applied" do
      assert Schedule.filter_by(%{}) == []
      refute Schedule.filter_by(%{routes: [@route.id]}) == []
      refute Schedule.filter_by(%{trips: [@trip.id]}) == []
      refute Schedule.filter_by(%{stops: [@stop.id]}) == []
    end

    test "filters on :stops" do
      assert Schedule.filter_by(%{stops: [@stop.id]}) == [@schedule]
      assert Schedule.filter_by(%{stops: [@stop.id, "bad_id"]}) == [@schedule]
      assert Schedule.filter_by(%{stops: ["bad_id"]}) == []
      assert Schedule.filter_by(%{stops: [""]}) == []
    end

    test "filters on :routes" do
      assert Schedule.filter_by(%{routes: [@route.id]}) == [@schedule]
      assert Schedule.filter_by(%{routes: [@route.id, "bad_id"]}) == [@schedule]
      assert Schedule.filter_by(%{routes: ["bad_id"]}) == []
      assert Schedule.filter_by(%{routes: []}) == []
    end

    test "filters on :trips" do
      assert Schedule.filter_by(%{trips: [@trip.id]}) == [@schedule]
      assert Schedule.filter_by(%{trips: [@trip.id, "bad_id"]}) == [@schedule]
      assert Schedule.filter_by(%{trips: ["bad_id"]}) == []
      assert Schedule.filter_by(%{trips: []}) == []
    end

    test "filters on :trips and :date" do
      assert Schedule.filter_by(%{trips: [@trip.id], date: @today}) == [@schedule]
      assert Schedule.filter_by(%{trips: [@trip.id], date: Timex.shift(@today, days: -1)}) == []
    end

    test "filters on :routes and :date" do
      bad_date = %{@today | year: @today.year - 1}
      params = %{routes: [@route.id], date: @today}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :routes, [])) == []
      assert Schedule.filter_by(Map.put(params, :date, bad_date)) == []
    end

    test "filters on :routes and :direction_id" do
      params = %{routes: [@route.id], direction_id: 1}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :direction_id, 0)) == []
      assert Schedule.filter_by(Map.put(params, :routes, [])) == []
    end

    test "filters on :routes, :date, and :direction_id" do
      bad_date = %{@today | year: @today.year - 1}
      params = %{routes: [@route.id], direction_id: 1, date: @today}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :direction_id, 0)) == []
      assert Schedule.filter_by(Map.put(params, :date, bad_date)) == []
      assert Schedule.filter_by(Map.put(params, :routes, [])) == []
    end

    test "filters on :stops and :trips" do
      params = %{stops: [@stop.id], trips: [@trip.id]}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :stops, [])) == []
      assert Schedule.filter_by(Map.put(params, :trips, [])) == []
    end

    test ":stops/:trips does not return multiple values for multi route trips" do
      # trips:
      # - solo_trip_id: only part of the main route
      # - other_trip_id: only part of the other route
      # - trip_id: part of both routes

      solo_trip_id = "solo_trip_id"
      other_route_id = "other_route"
      other_trip_id = "other_trip_id"
      route_pattern_id = "CR-Franklin-3-1"

      routes = [
        @route,
        %{@route | id: other_route_id}
      ]

      trips = [
        %{@trip | alternate_route: false, route_pattern_id: route_pattern_id},
        %{
          @trip
          | alternate_route: true,
            route_id: other_route_id,
            route_pattern_id: route_pattern_id
        },
        %{@trip | id: solo_trip_id},
        %{@trip | id: other_trip_id, route_id: other_route_id}
      ]

      schedules = [
        @schedule,
        %{@schedule | trip_id: solo_trip_id},
        %{@schedule | trip_id: other_trip_id, route_id: other_route_id}
      ]

      State.Route.new_state(routes)
      State.Trip.new_state(trips)
      Schedule.new_state(schedules)
      State.RoutesPatternsAtStop.update!()

      # we expect to only get the one schedule record back
      params = %{stops: [@stop.id], trips: [@trip.id]}
      assert Schedule.filter_by(params) == [@schedule]
    end

    test ":stops/:routes returns multi route trips, but not duplicates" do
      other_route_id = "other_route_id"

      routes = [
        @route,
        %{@route | id: other_route_id}
      ]

      trips = [
        %{@trip | alternate_route: false},
        %{
          @trip
          | alternate_route: true,
            route_id: other_route_id
        }
      ]

      schedules = [
        @schedule
      ]

      State.Route.new_state(routes)
      State.Trip.new_state(trips)
      Schedule.new_state(schedules)
      State.RoutesPatternsAtStop.update!()

      assert Enum.sort(Schedule.filter_by(%{stops: [@stop.id], routes: [@route.id]})) == [
               @schedule
             ]

      assert Enum.sort(Schedule.filter_by(%{stops: [@stop.id], routes: [other_route_id]})) == [
               @schedule
             ]
    end

    test "filters on :stops and :routes" do
      params = %{stops: [@stop.id], routes: [@route.id]}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :stops, [])) == []
      assert Schedule.filter_by(Map.put(params, :routes, [])) == []
    end

    test "filters on :stops and :date" do
      bad_date = %{@today | year: @today.year - 1}
      params = %{stops: [@stop.id], date: @today}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :stops, [])) == []
      assert Schedule.filter_by(Map.put(params, :date, bad_date)) == []
    end

    test "filters on :stops and :direction_id" do
      params = %{stops: [@stop.id], direction_id: 1}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :direction_id, 0)) == []
      assert Schedule.filter_by(Map.put(params, :stops, [])) == []
    end

    test "filters on :stop_sequence" do
      params = %{routes: [@route.id], stop_sequence: [2]}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :stop_sequence, [:first])) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :stop_sequence, [:last])) == []
      assert Schedule.filter_by(Map.put(params, :stops, [@stop.id])) == [@schedule]
    end

    test "filters on :min_time" do
      # 12:29:59 in seconds
      min_time = 44_999
      params = %{stops: [@stop.id], min_time: min_time}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :min_time, min_time + 1)) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :min_time, min_time + 2)) == []
    end

    test "filters on :max_time" do
      # 12:30:01 in seconds
      max_time = 45_001
      params = %{stops: [@stop.id], max_time: max_time}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :max_time, max_time - 1)) == [@schedule]
      assert Schedule.filter_by(Map.put(params, :max_time, max_time - 2)) == []
    end

    test "filters on :min_time and :max time" do
      # 12:29:59 in seconds
      min_time = 44_999
      # 12:30:01 in seconds
      max_time = 45_001
      params = %{stops: [@stop.id], min_time: min_time, max_time: max_time}
      bad_params = %{stops: [@stop.id], min_time: 10, max_time: 5_000}
      assert Schedule.filter_by(params) == [@schedule]
      assert Schedule.filter_by(bad_params) == []
    end
  end

  describe "handle_event" do
    test ~S|it does not handle_new_state until {:fetch, "stop_times.txt"}, {:new_state, State.Trip} are all received| do
      Schedule.new_state([])
      Schedule.reset_gather()

      {:ok, init_state, _} = Schedule.init([])

      callback_argument = nil

      assert {:noreply, stop_times_state, _} =
               Schedule.handle_event(
                 {:fetch, "stop_times.txt"},
                 """
                 "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint","checkpoint_id"
                 "Logan-22-Weekday-trip","08:00:00","08:00:00","Logan-Subway",1,"",0,1,0,""
                 "Logan-22-Weekday-trip","08:04:00","08:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
                 "Logan-22-Weekday-trip","08:09:00","08:09:00","Logan-A",3,"",0,0,0,""
                 "Logan-22-Weekday-trip","08:12:00","08:12:00","Logan-B",4,"",0,0,0,""
                 "Logan-22-Weekday-trip","08:17:00","08:17:00","Logan-Subway",5,"",1,0,0,""
                 "Logan-22-Weekday-trip","08:21:00","08:21:00","Logan-RentalCarCenter",6,"",1,0,0,""
                 "Logan-22-Weekday-trip","08:26:00","08:26:00","Logan-A",7,"",1,0,0,""
                 "Logan-22-Weekend-trip","12:00:00","12:00:00","Logan-Subway",1,"",0,1,0,""
                 "Logan-22-Weekend-trip","12:04:00","12:04:00","Logan-RentalCarCenter",2,"",0,0,0,""
                 "Logan-22-Weekend-trip","12:09:00","12:09:00","Logan-A",3,"",0,0,0,""
                 "Logan-22-Weekend-trip","12:12:00","12:12:00","Logan-B",4,"",0,0,0,""
                 "Logan-22-Weekend-trip","12:17:00","12:17:00","Logan-Subway",5,"",1,0,0,""
                 "Logan-22-Weekend-trip","12:21:00","12:21:00","Logan-RentalCarCenter",6,"",1,0,0,""
                 "Logan-22-Weekend-trip","12:26:00","12:26:00","Logan-A",7,"",1,0,0,""
                 """,
                 callback_argument,
                 init_state
               )

      assert State.Schedule.all() == []

      # Service must be set for trip to be valid
      State.Service.new_state([
        %Model.Service{
          id: "Logan-Weekday",
          start_date: @today,
          end_date: @today,
          added_dates: [@today]
        }
      ])

      State.Trip.new_state(%{
        multi_route_trips: [],
        trips: [
          %Model.Trip{
            id: "Logan-22-Weekday-trip",
            route_id: "Logan-22",
            service_id: "Logan-Weekday"
          }
        ]
      })

      assert trips = State.Trip.all()
      assert length(trips) == 1

      assert {:noreply, _, _} =
               Schedule.handle_event(
                 {:new_state, State.Trip},
                 trips,
                 callback_argument,
                 stop_times_state
               )

      refute Schedule.all() == []
    end
  end

  describe "schedule_for/1" do
    @today Timex.to_datetime(~D[2016-06-07], "America/New_York")
    @prediction %Model.Prediction{
      route_id: "route",
      trip_id: "trip",
      stop_id: "stop",
      stop_sequence: 2,
      direction_id: 1,
      arrival_time: Timex.set(@today, hour: 12, minute: 30),
      departure_time: Timex.set(@today, hour: 12, minute: 30)
    }
    @schedules [
      %Model.Schedule{
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
      },
      %Model.Schedule{
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
        stop_sequence: 1,
        position: :first
      },
      %Model.Schedule{
        route_id: "route",
        trip_id: "other_trip",
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
      },
      %Model.Schedule{
        route_id: "route",
        trip_id: "trip",
        stop_id: "other_stop",
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

    setup do
      State.Schedule.new_state(@schedules)
      State.RoutesPatternsAtStop.update!()
    end

    test "returns the schedule that has the same {trip, stop, stop_sequence}" do
      schedule = Schedule.schedule_for(@prediction)

      assert schedule.trip_id == @prediction.trip_id
      assert schedule.stop_id == @prediction.stop_id
      assert schedule.stop_sequence == @prediction.stop_sequence
    end

    test "returns the schedule if the prediction has been assigned to a different track" do
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
      prediction = %{@prediction | stop_id: "stop-01"}

      assert Schedule.schedule_for(prediction) == List.first(@schedules)
    end

    test "does not return a schedule for added predictions" do
      prediction = %{@prediction | schedule_relationship: :added}
      assert Schedule.schedule_for(prediction) == nil
    end
  end

  describe "schedule_for_many" do
    @today Timex.to_datetime(~D[2016-06-07], "America/New_York")
    @predictions [
      %Model.Prediction{
        route_id: "route",
        trip_id: "trip1",
        stop_id: "stop",
        stop_sequence: 1,
        direction_id: 1,
        arrival_time: Timex.set(@today, hour: 12, minute: 30),
        departure_time: Timex.set(@today, hour: 12, minute: 30)
      },
      %Model.Prediction{
        route_id: "route",
        trip_id: "trip2",
        stop_id: "stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: Timex.set(@today, hour: 12, minute: 30),
        departure_time: Timex.set(@today, hour: 12, minute: 30)
      }
    ]
    @schedule1 %Model.Schedule{
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
    }
    @schedule2 %Model.Schedule{
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

    setup do
      State.Route.new_state([%Model.Route{id: "route"}])
      State.Stop.new_state([%Model.Stop{id: "stop"}])

      State.Trip.new_state([
        %Model.Trip{id: "trip1", route_id: "route", direction_id: 1, service_id: "service"},
        %Model.Trip{id: "trip2", route_id: "route", direction_id: 1, service_id: "service"}
      ])

      State.Schedule.new_state([@schedule1, @schedule2])
      State.RoutesPatternsAtStop.update!()
    end

    test "returns schedules for multiple predictions" do
      assert Schedule.schedule_for_many(@predictions) == %{
               {"trip1", 1} => @schedule1,
               {"trip2", 2} => @schedule2
             }
    end

    test "does not return a schedule for added predictions" do
      prediction = %{List.first(@predictions) | schedule_relationship: :added}
      assert Schedule.schedule_for_many([prediction]) == %{}
    end
  end

  describe "filter_by_route_type/2" do
    @schedule2 %Model.Schedule{
      route_id: "route2",
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

    @route1 %Model.Route{id: "route", type: 0}
    @route2 %Model.Route{id: "route2", type: 1}

    test "returns all predictions if no filters set" do
      State.Route.new_state([@route1, @route2])

      assert Schedule.filter_by_route_type([@schedule, @schedule2], nil) == [
               @schedule,
               @schedule2
             ]

      assert Schedule.filter_by_route_type([@schedule, @schedule2], []) == [@schedule, @schedule2]
    end

    test "filters by route_type" do
      State.Route.new_state([@route1, @route2])
      assert Schedule.filter_by_route_type([@schedule, @schedule2], [0]) == [@schedule]
      assert Schedule.filter_by_route_type([@schedule, @schedule2], [1]) == [@schedule2]

      assert Schedule.filter_by_route_type([@schedule, @schedule2], [0, 1]) == [
               @schedule,
               @schedule2
             ]

      assert Schedule.filter_by_route_type([@schedule, @schedule2], [2]) == []
    end
  end
end
