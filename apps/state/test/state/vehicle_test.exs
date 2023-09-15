defmodule State.VehicleTest do
  @moduledoc false
  use ExUnit.Case

  alias Model.{Route, Trip, Vehicle}
  import State.Vehicle

  setup _ do
    State.Trip.new_state([])
    new_state([])
    :ok
  end

  test "returns nil for unknown vehicles" do
    assert by_id("1") == nil
    assert by_trip_id("1") == []
    assert all() == []
  end

  test "it can add a vehicle and query it by trip ID" do
    vehicle = %Vehicle{id: "1", trip_id: "2"}
    new_state([vehicle])

    assert %Vehicle{id: "1"} = by_id("1")
    assert Vehicle.primary?(by_id("1"))
    assert [%Vehicle{id: "1"}] = by_trip_id("2")
    assert [%Vehicle{id: "1"}] = match(%{trip_id: "2", id: "1"}, :trip_id)
    assert [%Vehicle{id: "1"}] = all()
  end

  test "can add a vehicle and query it by label" do
    vehicle = %Vehicle{id: "1", label: "2"}
    new_state([vehicle])

    assert [%Vehicle{id: "1"}] = filter_by(%{labels: ["2"]})
  end

  test "querying by label matches individual car labels in consist" do
    vehicle = %Vehicle{id: "1", label: "1400-1401", consist: MapSet.new(["1400", "1401"])}
    new_state([vehicle])

    assert [%Vehicle{id: "1"}] = filter_by(%{labels: ["1401"]})
  end

  test "can add vehicle and query it by route_type" do
    route = %Route{id: "route", type: 1}
    State.Route.new_state([route])

    vehicle = %Vehicle{id: "1", route_id: "route", effective_route_id: "route"}
    new_state([vehicle])

    assert [vehicle] == filter_by(%{route_types: [1]})
    assert [] == filter_by(%{route_types: [0]})
  end

  test "can add vehicle and query it by route and direction_id" do
    vehicle = %Vehicle{id: "1", route_id: "route", effective_route_id: "route", direction_id: 1}
    new_state([vehicle])

    assert [vehicle] == filter_by(%{routes: ["route"]})
    assert [vehicle] == filter_by(%{routes: ["route"], direction_id: 1})
    assert [] == filter_by(%{routes: ["route"], direction_id: 0})
    assert [vehicle] == filter_by(%{direction_id: 0})
  end

  test "can add vehicle from multiple routes and query it" do
    State.Trip.new_state([
      %Trip{id: "1", route_id: "1", alternate_route: false},
      %Trip{id: "1", route_id: "2", alternate_route: true}
    ])

    new_state([%Vehicle{id: "veh", trip_id: "1", route_id: "1"}])

    assert [%Vehicle{id: "veh"} = vehicle] = all()
    assert Vehicle.primary?(vehicle)
    assert [%Vehicle{id: "veh"} = vehicle] = by_effective_route_id("1")
    assert Vehicle.primary?(vehicle)
    assert [%Vehicle{id: "veh"} = vehicle_alt] = by_effective_route_id("2")
    refute Vehicle.primary?(vehicle_alt)
  end

  test "it can return multiple vehicles on the same route" do
    new_state([
      %Vehicle{id: "one", trip_id: "1", route_id: "1"},
      %Vehicle{id: "two", trip_id: "2", route_id: "1"}
    ])

    assert [_, _] = all()
  end

  test "it can accept a partial update which only modifies some vehicles" do
    new_state([
      %Vehicle{id: "one", trip_id: "1", route_id: "1"},
      %Vehicle{id: "two", trip_id: "2", route_id: "1"}
    ])

    new_state(
      {:partial,
       [
         %Vehicle{id: "one", trip_id: "3", route_id: "1"}
       ]}
    )

    assert %Vehicle{id: "one", trip_id: "3"} = by_id("one")
    assert %Vehicle{id: "two", trip_id: "2"} = by_id("two")
  end

  @tag :capture_log
  test "an invalid state doesn't crash the server" do
    vehicle = %Vehicle{id: "1", trip_id: "2"}
    new_state([vehicle])

    new_state("here's some text!")

    assert size() == 1
  end
end
