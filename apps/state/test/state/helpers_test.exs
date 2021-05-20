defmodule State.HelpersTest do
  use ExUnit.Case
  alias Model.{RoutePattern, Trip}
  import State.Helpers

  describe "stops_on_route?/1" do
    setup do
      State.RoutePattern.new_state([])
      :ok
    end

    test "returns false for trips with a route_type" do
      refute stops_on_route?(%Trip{route_type: 3})
    end

    test "returns false for trips that are in multi_route_trips" do
      refute stops_on_route?(%Trip{alternate_route: true})
      refute stops_on_route?(%Trip{alternate_route: false})
    end

    test "returns false for trips with atypical patterns" do
      route_pattern_id = "pattern"
      State.RoutePattern.new_state([%RoutePattern{id: route_pattern_id, typicality: 4}])

      refute stops_on_route?(%Trip{route_pattern_id: route_pattern_id})
    end

    test "returns true for trips with normal patterns" do
      route_pattern_id = "pattern"
      State.RoutePattern.new_state([%RoutePattern{id: route_pattern_id, typicality: 1}])

      assert stops_on_route?(%Trip{route_pattern_id: route_pattern_id})
    end

    test "returns the configured value if the route pattern matches an override" do
      # has a prefix defined in `route_pattern_prefix_overrides`
      route_pattern_id = "CR-Franklin-Foxboro-extra-chars"

      assert stops_on_route?(%Trip{
               route_pattern_id: route_pattern_id,
               route_type: 3,
               alternate_route: false
             })
    end
  end
end
