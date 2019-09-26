defmodule State.HelpersTest do
  use ExUnit.Case
  import State.Helpers

  alias Model.{Trip, RoutePattern}

  describe "ignore_trip_route_pattern?/1" do
    setup do
      State.RoutePattern.new_state([])

      :ok
    end

    test "ignores trips with a route_type" do
      assert ignore_trip_route_pattern?(%Trip{route_type: 3})
    end

    test "ignores trips that are in multi_route_trips" do
      assert ignore_trip_route_pattern?(%Trip{alternate_route: true})
      assert ignore_trip_route_pattern?(%Trip{alternate_route: false})
    end

    test "ignores trips with atypical patterns" do
      route_pattern_id = "pattern"
      State.RoutePattern.new_state([%RoutePattern{id: route_pattern_id, typicality: 4}])
      assert ignore_trip_route_pattern?(%Trip{route_pattern_id: route_pattern_id})
    end

    test "does not ignore trips with normal patterns" do
      route_pattern_id = "pattern"
      State.RoutePattern.new_state([%RoutePattern{id: route_pattern_id, typicality: 1}])
      refute ignore_trip_route_pattern?(%Trip{route_pattern_id: route_pattern_id})
    end

    test "allows overriding the ignore value" do
      route_pattern_id = "CR-Franklin-3-0"

      refute ignore_trip_route_pattern?(%Trip{
               route_pattern_id: route_pattern_id,
               route_type: 3,
               alternate_route: false
             })
    end
  end
end
