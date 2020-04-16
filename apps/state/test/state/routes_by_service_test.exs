defmodule State.RoutesByServiceTest do
  use ExUnit.Case
  use Timex
  import State.RoutesByService
  import ExUnit.CaptureLog

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
    route_pattern_id: "route_pattern",
    direction_id: 1,
    service_id: "service"
  }

  setup_all do
    Logger.configure(level: :info)
    State.Stop.new_state([])
    State.Route.new_state([@route])
    State.Trip.new_state([@trip])
    State.Service.new_state([@service])
    State.Shape.new_state([])
    update!()

    on_exit(fn ->
      Logger.configure(level: :warn)
    end)
  end

  describe "for_service_id/1" do
    test "returns the route IDs for a given service" do
      assert for_service_id(@service.id) == [@route.id]
    end

    test "returns an empty list if no match for service id" do
      assert for_service_id("some_other_service") == []
    end
  end

  describe "crash" do
    @tag timeout: 1_000
    test "rebuilds properly if it's restarted" do
      assert capture_log([level: :info], fn ->
               State.Route.new_state([@route])
               State.Trip.new_state([@trip])
               State.Service.new_state([@service])

               GenServer.stop(State.RoutesByService)
               await_size(State.RoutesByService)
             end) =~ "Update #{State.RoutesByService}"
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
