defmodule State.VehicleTest do
  @moduledoc false
  use ExUnit.Case

  alias Model.{Trip, Vehicle}
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

    assert [%Vehicle{id: "1"}] = by_label("2")
    assert [%Vehicle{id: "1"}] = match(%{label: "2", id: "1"}, :label)
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

  @tag :capture_log
  test "an invalid state doesn't crash the server" do
    vehicle = %Vehicle{id: "1", trip_id: "2"}
    new_state([vehicle])

    new_state("here's some text!")

    assert size() == 1
  end
end
