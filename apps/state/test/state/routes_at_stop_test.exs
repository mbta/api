defmodule State.RoutesAtStopTest do
  use ExUnit.Case
  use Timex
  import State.RoutesAtStop

  @route %Model.Route{id: "route"}
  @service %Model.Service{
    id: "service",
    start_date: Timex.today(),
    end_date: Timex.today(),
    added_dates: [Timex.today()]
  }
  @trip %Model.Trip{
    id: "trip",
    shape_id: "pattern",
    route_id: "route",
    direction_id: 1,
    service_id: "service",
    route_pattern_id: "rpi"
  }
  @other_trip %Model.Trip{
    id: "other_trip",
    shape_id: "other_pattern",
    route_id: "route",
    direction_id: 0,
    service_id: "other_service",
    route_pattern_id: "other_rpi"
  }
  @schedule %Model.Schedule{trip_id: "trip", stop_id: "stop", stop_sequence: 2}
  @other_schedule %Model.Schedule{trip_id: "other_trip", stop_id: "other_stop", stop_sequence: 1}

  setup do
    State.Stop.new_state([])
    State.Route.new_state([@route])
    State.Trip.new_state([@trip, @other_trip])
    State.Service.new_state([@service])
    State.Schedule.new_state([@schedule, @other_schedule])
    State.Shape.new_state([])
    update!()
  end

  describe "by_stop_and_direction/2" do
    test "returns the route IDs at a given stop" do
      assert by_stop_and_direction("stop", direction_id: 0) == []
      assert by_stop_and_direction("stop", direction_id: 1) == ["route"]
      assert by_stop_and_direction("other_stop", direction_id: 0) == ["route"]
      assert by_stop_and_direction("other_stop", direction_id: 1) == []
      assert by_stop_and_direction("stop") == ["route"]
      assert by_stop_and_direction("unknown") == []
      assert by_stop_and_direction("stop", service_ids: ["service"]) == ["route"]
      assert by_stop_and_direction("stop", service_ids: ["other_service"]) == []
    end

    test "ignores routes which are only on ignored shapes" do
      shape = %Model.Shape{
        id: @trip.shape_id,
        priority: -1
      }

      trip = %{@trip | route_type: 2}
      State.Trip.new_state([trip, @other_trip])
      State.Shape.new_state([shape])
      update!()
      assert by_stop_and_direction("stop", direction_id: 1) == []
    end
  end

  describe "by_family_stops/2" do
    test "returns routes that stop at any member of the route's family" do
      State.Stop.new_state([
        %Model.Stop{id: "stop", parent_station: "parent"},
        %Model.Stop{id: "sibling", parent_station: "parent"},
        %Model.Stop{id: "parent", location_type: 1}
      ])

      update!()
      expected = by_stop_and_direction("stop")
      assert by_family_stops(["stop"]) == expected
      assert by_family_stops(["parent"]) == expected
      # doesn't go back down the tree
      assert by_family_stops(["sibling"]) == []
      assert by_family_stops(["stop"], direction_id: 0) == []
      assert by_family_stops(["parent"], direction_id: 0) == []
    end
  end

  test "doesn't override itself if there are no schedules" do
    State.Schedule.new_state([])
    update!()

    assert by_stop_and_direction("stop", direction_id: 1) == ["route"]
  end

  describe "crash" do
    @tag timeout: 1_000
    test "rebuilds properly if it's restarted" do
      State.Stop.new_state([])
      State.Route.new_state([@route])
      State.Trip.new_state([@trip, @other_trip])
      State.Service.new_state([@service])
      State.Schedule.new_state([@schedule, @other_schedule])

      GenServer.stop(State.RoutesAtStop)
      await_size(State.RoutesAtStop)
    end

    defp await_size(module) do
      # waits for the module to have a size > 0: eventually the test will
      # timeout if this doesn't happen
      if module.size() > 0 do
        :ok
      else
        await_size(module)
      end
    end
  end
end
