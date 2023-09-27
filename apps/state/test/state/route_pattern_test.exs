defmodule State.RoutePatternTest do
  use ExUnit.Case

  alias Model.RoutePattern
  import State.RoutePattern

  describe "filter_by/1" do
    test "filters by ids" do
      route_pattern = %RoutePattern{id: "pattern", route_id: "route"}
      other_pattern = %RoutePattern{id: "other", route_id: "route"}

      State.RoutePattern.new_state([route_pattern, other_pattern])

      assert filter_by(%{ids: ["pattern"]}) == [route_pattern]
      assert Enum.sort(filter_by(%{ids: ["pattern", "other"]})) == [other_pattern, route_pattern]
      assert filter_by(%{ids: ["not_a_pattern"]}) == []
      assert filter_by(%{ids: []}) == []
      assert Enum.sort(filter_by(%{})) == [other_pattern, route_pattern]
    end

    test "filters by route, stop, direction and canonical" do
      route = %Model.Route{id: "route"}
      route_pattern = %RoutePattern{id: "pattern", route_id: route.id, canonical: true}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        direction_id: 0
      }

      stop = %Model.Stop{id: "stop"}
      schedule = %Model.Schedule{trip_id: trip.id, stop_id: stop.id, route_id: route.id}

      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.RoutePattern.new_state([route_pattern])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()

      assert filter_by(%{stop_ids: ["stop"]}) == [route_pattern]
      assert filter_by(%{stop_ids: ["not_stop"]}) == []
      assert filter_by(%{stop_ids: ["stop"], direction_id: 0}) == [route_pattern]
      assert filter_by(%{stop_ids: ["stop"], direction_id: 1}) == []
      assert filter_by(%{route_ids: ["route"], direction_id: 0}) == [route_pattern]
      assert filter_by(%{route_ids: ["route"], direction_id: 1}) == []
      assert filter_by(%{route_ids: ["route"], stop_ids: ["stop"]}) == [route_pattern]
      assert filter_by(%{route_ids: ["not_route"], stop_ids: ["stop"]}) == []
      assert filter_by(%{canonical: true}) == [route_pattern]
      assert filter_by(%{canonical: false}) == []
      assert filter_by(%{stop_ids: ["stop"], canonical: true}) == [route_pattern]
      assert filter_by(%{stop_ids: ["not_stop"], canonical: true}) == []
    end

    test "includes child stops" do
      route = %Model.Route{id: "route"}
      route_pattern0 = %RoutePattern{id: "pattern0", route_id: route.id, direction_id: 0}
      route_pattern1 = %RoutePattern{id: "pattern1", route_id: route.id, direction_id: 1}
      route_patterns = [route_pattern0, route_pattern1]

      stops = [
        %Model.Stop{id: "stop", location_type: 1},
        %Model.Stop{id: "child0", parent_station: "stop"},
        %Model.Stop{id: "child1", parent_station: "stop"}
      ]

      trips = [
        %Model.Trip{
          id: "trip0",
          route_id: route.id,
          route_pattern_id: "pattern0",
          direction_id: 0
        },
        %Model.Trip{
          id: "trip1",
          route_id: route.id,
          route_pattern_id: "pattern1",
          direction_id: 1
        }
      ]

      schedules = [
        %Model.Schedule{trip_id: "trip0", stop_id: "child0", route_id: route.id},
        %Model.Schedule{trip_id: "trip1", stop_id: "child1", route_id: route.id}
      ]

      State.Stop.new_state(stops)
      State.Route.new_state([route])
      State.RoutePattern.new_state(route_patterns)
      State.Trip.new_state(trips)
      State.Schedule.new_state(schedules)
      State.RoutesPatternsAtStop.update!()

      assert Enum.sort(filter_by(%{stop_ids: ["stop"]})) == Enum.sort(route_patterns)
      assert filter_by(%{stop_ids: ["child0"]}) == [route_pattern0]
      assert filter_by(%{stop_ids: ["child1"]}) == [route_pattern1]
    end

    test "includes alternate route" do
      route = %Model.Route{id: "route"}
      other_route = %Model.Route{id: "other_route"}
      route_pattern = %Model.RoutePattern{id: "1", route_id: route.id}
      other_pattern = %Model.RoutePattern{id: "2", route_id: other_route.id}

      normal_trip = %Model.Trip{id: "t1", route_id: route.id, route_pattern_id: route_pattern.id}

      primary_trip = %Model.Trip{
        id: "t2",
        route_id: other_route.id,
        route_pattern_id: other_pattern.id,
        alternate_route: false
      }

      alternate_trip = %Model.Trip{
        id: "t2",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        alternate_route: true
      }

      State.Route.new_state([route, other_route])
      State.RoutePattern.new_state([route_pattern, other_pattern])
      State.Trip.new_state([normal_trip, primary_trip, alternate_trip])

      assert filter_by(%{route_ids: ["route"]}) == [route_pattern, other_pattern]
      assert filter_by(%{route_ids: ["other_route"]}) == [other_pattern]
    end

    test "includes alternate route when filtering by stop_ids" do
      route = %Model.Route{id: "route"}
      other_route = %Model.Route{id: "other_route"}
      route_pattern = %Model.RoutePattern{id: "1", route_id: route.id}
      other_pattern = %Model.RoutePattern{id: "2", route_id: other_route.id}

      normal_trip = %Model.Trip{id: "t1", route_id: route.id, route_pattern_id: route_pattern.id}

      primary_trip = %Model.Trip{
        id: "t2",
        route_id: other_route.id,
        route_pattern_id: other_pattern.id,
        alternate_route: false
      }

      alternate_trip = %Model.Trip{
        id: "t2",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        alternate_route: true
      }

      stop = %Model.Stop{id: "stop"}
      schedule = %Model.Schedule{trip_id: alternate_trip.id, stop_id: stop.id, route_id: route.id}

      State.Route.new_state([route, other_route])
      State.RoutePattern.new_state([route_pattern, other_pattern])
      State.Trip.new_state([normal_trip, primary_trip, alternate_trip])
      State.Stop.new_state([stop])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()

      assert filter_by(%{stop_ids: ["stop"]}) == [route_pattern, other_pattern]
      # normal trip uses route_pattern and alternate trip uses other_pattern
      assert filter_by(%{stop_ids: ["stop"], route_ids: ["route"]}) == [
               route_pattern,
               other_pattern
             ]

      # only primary_trip uses other_pattern
      assert filter_by(%{stop_ids: ["stop"], route_ids: ["other_route"]}) == [other_pattern]
    end
  end
end
