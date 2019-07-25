defmodule State.RoutePatternTest do
  use ExUnit.Case

  alias Model.RoutePattern
  import State.RoutePattern

  describe "filter_by/1" do
    test "filters by stop id and direction" do
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

      assert filter_by(%{stop_ids: ["stop"]}) == [route_pattern]
      assert filter_by(%{stop_ids: ["not_at_stop"]}) == []
      assert filter_by(%{stop_ids: ["stop"], direction_id: 0}) == [route_pattern]
      assert filter_by(%{stop_ids: ["stop"], direction_id: 1}) == []
    end
  end
end
