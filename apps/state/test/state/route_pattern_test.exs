defmodule State.RoutePatternTest do
  use ExUnit.Case

  alias Model.RoutePattern
  import State.RoutePattern

  describe "filter_by/1" do
    test "filters by ids" do
      route_pattern = %RoutePattern{id: "pattern", route_id: "route"}
      other_pattern = %RoutePattern{id: "other", route_id: "route"}

      State.RoutePattern.new_state([route_pattern, other_pattern])

      assert filter_by(%{id: ["pattern"]}) == [route_pattern]
      assert Enum.sort(filter_by(%{id: ["pattern", "other"]})) == [other_pattern, route_pattern]
      assert filter_by(%{id: ["not_a_pattern"]}) == []
      assert filter_by(%{id: []}) == []
      assert Enum.sort(filter_by(%{})) == [other_pattern, route_pattern]
    end

    test "filters by route, stop and direction" do
      route = %Model.Route{id: "route"}
      route_pattern = %RoutePattern{id: "pattern", route_id: route.id}

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

      assert filter_by(%{stop_id: ["stop"]}) == [route_pattern]
      assert filter_by(%{stop_id: ["not_stop"]}) == []
      assert filter_by(%{stop_id: ["stop"], direction_id: 0}) == [route_pattern]
      assert filter_by(%{stop_id: ["stop"], direction_id: 1}) == []
      assert filter_by(%{route_id: ["route"], direction_id: 0}) == [route_pattern]
      assert filter_by(%{route_id: ["route"], direction_id: 1}) == []
      assert filter_by(%{route_id: ["route"], stop_id: ["stop"]}) == [route_pattern]
      assert filter_by(%{route_id: ["not_route"], stop_id: ["stop"]}) == []
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

      assert filter_by(%{route_id: ["route"]}) == [route_pattern, other_pattern]
      assert filter_by(%{route_id: ["other_route"]}) == [other_pattern]
    end
  end
end
