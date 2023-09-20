defmodule State.TripTest do
  use ExUnit.Case

  import State.Trip

  alias Parse.Time
  alias State.Service

  # Constants

  @service_id "service"
  @trip_id "trip"
  @trip %Model.Trip{
    block_id: "block_id",
    id: @trip_id,
    route_id: "9",
    direction_id: 1,
    service_id: @service_id,
    name: "name"
  }
  @today Time.service_date()
  @service %Model.Service{
    id: @service_id,
    start_date: @today,
    end_date: @today,
    added_dates: [@today]
  }

  setup do
    # Reset received keys
    reset_gather()

    Service.new_state([@service])
    new_state(%{multi_route_trips: [], trips: [@trip]})
  end

  test "init" do
    assert {:ok, %{data: _, last_updated: nil}, :hibernate} = init([])
  end

  test "returns nil for unknown trips" do
    assert by_id("unknown") == []
    assert by_ids(["unknown"]) == []
    assert by_primary_id("unknown") == nil
    assert by_route_id("unknown") == []
  end

  test "can query trips" do
    assert by_id("trip") == [@trip]
    assert by_ids(["trip"]) == [@trip]
    assert by_primary_id("trip") == @trip
    assert by_route_id("9") == [@trip]
  end

  test "can query added trips (which include a headsign)" do
    added_trip_id = "ADDED-1"
    added_route_id = "Green-C"
    added_direction_id = 1

    stops = [
      %Model.Stop{id: "other"},
      %Model.Stop{id: "child", parent_station: "parent"},
      %Model.Stop{id: "parent", name: "Stop Name"}
    ]

    base_prediction = %Model.Prediction{
      trip_id: added_trip_id,
      route_id: added_route_id,
      direction_id: added_direction_id,
      schedule_relationship: :added
    }

    predictions = [
      %{base_prediction | stop_id: "other", stop_sequence: 0},
      %{base_prediction | stop_id: "child", stop_sequence: 1}
    ]

    State.Stop.new_state(stops)
    State.Prediction.new_state(predictions)
    State.Trip.Added.last_updated()

    expected = %Model.Trip{
      id: added_trip_id,
      route_id: added_route_id,
      direction_id: added_direction_id,
      headsign: "Stop Name",
      name: "",
      wheelchair_accessible: 1,
      bikes_allowed: 0
    }

    assert by_primary_id(added_trip_id) == expected
  end

  describe "by_primary_id/1" do
    test "filters out alternate route trips" do
      alternate = %{@trip | alternate_route: true, route_id: "10"}
      new_state(%{multi_route_trips: [], trips: [@trip, alternate]})
      assert by_primary_id(@trip.id) == @trip
    end

    test "does not filter out the primary version of an alernate" do
      primary = %{@trip | alternate_route: false}
      alternate = %{@trip | alternate_route: true, route_id: "10"}
      new_state(%{multi_route_trips: [], trips: [primary, alternate]})
      assert by_primary_id(@trip.id) == primary
    end
  end

  describe "handle_event" do
    test ~S|it does not handle_new_state until {:fetch, "multi_route_trips.txt"}, {:fetch, "trips.txt"}, and | <>
           "{:new_state, State.Service} are all received" do
      # Clear ETS table
      new_state(%{multi_route_trips: [], trips: []})

      # Clear state in GenServer, so it doesn't trigger a write to ETS table earlier than direct `handle_event` calls
      reset_gather()

      {:ok, init_state, _} = init([])

      callback_argument = nil

      assert {:noreply, multi_route_trips_state, :hibernate} =
               handle_event(
                 {:fetch, "multi_route_trips.txt"},
                 """
                 "added_route_id","trip_id"
                 "Logan-23","Logan-22-Weekday-trip"
                 """,
                 callback_argument,
                 init_state
               )

      assert all() == []

      assert {:noreply, trips_state, :hibernate} =
               handle_event(
                 {:fetch, "trips.txt"},
                 """
                 "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","trip_route_type","route_pattern_id"
                 "Logan-22","Logan-Weekday","Logan-22-Weekday-trip","Loop","",0,"","",1,"","Logan-22-1-0"
                 """,
                 callback_argument,
                 multi_route_trips_state
               )

      assert all() == []

      # Trip calls `Service.valid_in_future`, so it's state needs to be updated for that direct call
      service_state = [
        %Model.Service{
          id: "Logan-Weekday",
          start_date: @today,
          end_date: @today,
          added_dates: [@today]
        }
      ]

      Service.new_state(service_state)

      # Event needs to be sent in case `Service.new_state` `{:new_state, Service}` event is not seen by this time
      assert {:noreply, _, :hibernate} =
               handle_event(
                 {:new_state, Service},
                 service_state,
                 callback_argument,
                 trips_state
               )

      assert [
               %Model.Trip{
                 alternate_route: false,
                 id: "Logan-22-Weekday-trip",
                 route_id: "Logan-22",
                 service_id: "Logan-Weekday"
               },
               %Model.Trip{
                 alternate_route: true,
                 id: "Logan-22-Weekday-trip",
                 route_id: "Logan-23",
                 service_id: "Logan-Weekday"
               }
             ] = Enum.sort(all())
    end
  end

  describe "handle_new_state" do
    test "includes trips with valid services" do
      new_state(%{multi_route_trips: [], trips: [@trip]})

      assert all() == [@trip]
    end

    test "creates alternate route for Silver Line Waterfront" do
      trip_id = "trip_id"

      trip = %Model.Trip{
        alternate_route: nil,
        id: trip_id,
        route_id: "746",
        service_id: @service_id
      }

      new_state(%{
        multi_route_trips: [
          %Model.MultiRouteTrip{added_route_id: "741", trip_id: trip_id},
          %Model.MultiRouteTrip{added_route_id: "742", trip_id: trip_id}
        ],
        trips: [trip]
      })

      assert [%Model.Trip{alternate_route: false, id: id, route_id: "746"}] = by_route_id("746")
      assert [%Model.Trip{alternate_route: true, id: ^id, route_id: "741"}] = by_route_id("741")
      assert [%Model.Trip{alternate_route: true, id: ^id, route_id: "742"}] = by_route_id("742")
    end

    test "creates alternate for CR-Haverhill" do
      trip_id = "221"

      trip = %Model.Trip{
        alternate_route: nil,
        id: trip_id,
        route_id: "CR-Haverhill",
        service_id: @service_id
      }

      new_state(%{
        multi_route_trips: [
          %Model.MultiRouteTrip{added_route_id: "CR-Haverhill", trip_id: trip_id},
          %Model.MultiRouteTrip{added_route_id: "CR-Lowell", trip_id: trip_id}
        ],
        trips: [trip]
      })

      assert [%Model.Trip{alternate_route: false, id: ^trip_id, route_id: "CR-Haverhill"}] =
               by_route_id("CR-Haverhill")

      assert [%Model.Trip{alternate_route: true, id: ^trip_id, route_id: "CR-Lowell"}] =
               by_route_id("CR-Lowell")
    end
  end

  describe "filter_by/1" do
    test "returns empty list when no filters are provided" do
      assert filter_by(%{}) == []
    end

    test "filters by multiple ids" do
      trips = [
        trip1 = %Model.Trip{id: "1", route_id: "3", service_id: @service_id},
        trip2 = %Model.Trip{id: "2", route_id: "3", service_id: @service_id},
        trip3 = %Model.Trip{id: "3", route_id: "3", service_id: @service_id}
      ]

      new_state(%{multi_route_trips: [], trips: trips})
      assert filter_by(%{ids: ["1", "3"]}) == [trip1, trip3]
      assert filter_by(%{ids: ["2", "badid"]}) == [trip2]
    end

    test "filters by multiple ids and route id" do
      trips = [
        _trip1 = %Model.Trip{id: "1", route_id: "1", service_id: @service_id},
        trip2 = %Model.Trip{id: "2", route_id: "2", service_id: @service_id},
        _trip3 = %Model.Trip{id: "3", route_id: "3", service_id: @service_id}
      ]

      new_state(%{multi_route_trips: [], trips: trips})
      assert filter_by(%{ids: ["1", "2"], routes: ["2", "3"]}) == [trip2]
      assert filter_by(%{ids: ["1", "2", "3"], routes: ["2"]}) == [trip2]
      assert filter_by(%{ids: ["1", "2", "3"], routes: ["4"]}) == []
    end

    test "filters by route pattern w/ and w/o other fields" do
      trips = [
        trip1 = %Model.Trip{
          id: "1",
          route_id: "1",
          service_id: @service_id,
          direction_id: 1,
          route_pattern_id: "1-1-1"
        },
        trip2 = %Model.Trip{
          id: "2",
          route_id: "2",
          service_id: @service_id,
          direction_id: 1,
          route_pattern_id: "2-1-1"
        },
        trip3 = %Model.Trip{
          id: "3",
          route_id: "3",
          service_id: @service_id,
          direction_id: 0,
          route_pattern_id: "3-0-1"
        }
      ]

      new_state(%{multi_route_trips: [], trips: trips})
      assert filter_by(%{ids: ["1", "2"], route_patterns: ["1-1-1", "2-1-1"]}) == [trip1, trip2]
      assert filter_by(%{route_patterns: ["1-1-1", "3-0-1"], routes: ["3"]}) == [trip3]
      assert filter_by(%{route_patterns: ["2-1-1", "3-0-1"]}) == [trip2, trip3]
      assert filter_by(%{route_patterns: ["2-1-1", "3-0-1"], direction_id: 0}) == [trip3]
    end

    test "returns primary routes for alternate trips" do
      trips = [
        %Model.Trip{id: "1", route_id: "3", service_id: @service_id, alternate_route: true},
        trip = %Model.Trip{
          id: "1",
          route_id: "4",
          service_id: @service_id,
          alternate_route: false
        }
      ]

      new_state(%{multi_route_trips: [], trips: trips})

      assert filter_by(%{routes: ["3"]}) == [trip]
    end

    test "filters by routes" do
      assert filter_by(%{routes: ["9"]}) == [@trip]
      assert filter_by(%{routes: ["badid"]}) == []
    end

    test "filters by routes and direction id" do
      assert filter_by(%{routes: ["9"], direction_id: 1}) == [@trip]
      assert filter_by(%{routes: ["9"], direction_id: 0}) == []
    end

    test "filters by service date" do
      bad_date = %{@today | year: @today.year - 1}

      assert filter_by(%{date: @today, routes: ["9"]}) == [@trip]
      assert filter_by(%{date: bad_date, routes: ["9"]}) == []
    end

    test "filters by name" do
      assert filter_by(%{names: ["name"]}) == [@trip]
      assert filter_by(%{names: ["not_a_name"]}) == []
    end
  end
end
