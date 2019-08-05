defmodule State.StopTest do
  use ExUnit.Case
  import State.Stop
  alias Model.Stop

  setup do
    State.Stop.new_state([])

    :ok
  end

  test "returns nil for unknown stops" do
    assert State.Stop.by_id("unknown") == nil
  end

  test "it can add a stop and query it" do
    stop = %Stop{id: "1", name: "stop", latitude: 1, longitude: -2}
    State.Stop.new_state([stop])

    assert State.Stop.around(1.001, -2.002) == [stop]
    assert State.Stop.by_id(stop.id) == stop
  end

  test "it can limit the search to a radius" do
    stop = %Stop{id: "2", name: "stop", latitude: 1, longitude: -2}
    State.Stop.new_state([stop])

    assert State.Stop.around(1.001, -2.002, 0.001) == []
  end

  test "it can return all stops" do
    stop = %Stop{id: "3"}
    stop2 = %Stop{id: "4"}
    State.Stop.new_state([stop, stop2])
    assert State.Stop.all() |> Enum.sort() == [stop, stop2]
  end

  test "can query IDs and return family members (parents/children)" do
    parent = %Stop{id: "5", location_type: 1}
    child = %Stop{id: "6", parent_station: "5"}
    other_child = %Stop{id: "6-2", parent_station: "5"}
    other = %Stop{id: "7"}
    State.Stop.new_state([parent, child, other_child, other])

    assert Enum.sort(State.Stop.by_family_ids([parent.id])) ==
             Enum.sort([parent, child, other_child])

    assert State.Stop.by_family_ids([child.id]) == [child]

    assert Enum.sort(State.Stop.by_family_ids([parent.id, child.id])) ==
             Enum.sort([parent, child, other_child])

    assert State.Stop.by_family_ids([other.id]) == [other]
    assert State.Stop.by_parent_station(parent.id) == [child, other_child]
    assert State.Stop.siblings(child.id) == [child, other_child]
  end

  describe "by_parent_station/1" do
    setup do
      parent = %Stop{id: "5", location_type: 1}
      child = %Stop{id: "6", parent_station: "5"}
      other = %Stop{id: "7"}
      new_state([parent, child, other])
      {:ok, %{parent: parent, child: child, other: other}}
    end

    test "returns the children of a parent", stops do
      assert by_parent_station(stops.parent.id) == [stops.child]
    end

    test "returns nothing if the stop isn't a parent station", stops do
      assert by_parent_station(stops.other.id) == []
    end
  end

  describe "location_type_0_ids_by_parent_ids/1" do
    setup do
      parent = %Stop{id: "5", location_type: 1}
      child = %Stop{id: "6", parent_station: "5"}
      entrance = %Stop{id: "ent", parent_station: "5", location_type: 2}
      node = %Stop{id: "node", parent_station: "5", location_type: 3}
      other = %Stop{id: "7"}
      new_state([parent, child, entrance, node, other])
      {:ok, %{parent: parent, child: child, other: other}}
    end

    test "returns the IDs of stops with location_type 0", stops do
      assert location_type_0_ids_by_parent_ids([stops.child.id]) == [stops.child.id]
      assert location_type_0_ids_by_parent_ids([stops.parent.id]) == [stops.child.id]

      assert Enum.sort(location_type_0_ids_by_parent_ids([stops.other.id, stops.parent.id])) == [
               stops.child.id,
               stops.other.id
             ]
    end
  end

  describe "filter_by/1" do
    test "lists all stops when no filters are given" do
      stops =
        for i <- 1..4 do
          %Stop{id: "#{i}"}
        end

      :ok = State.Stop.new_state(stops)

      sorted_results =
        %{}
        |> State.Stop.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == stops
    end

    test "filters by id" do
      stops =
        for id <- ~w(one two three) do
          %Stop{id: id}
        end

      :ok = State.Stop.new_state(stops)

      sorted_results =
        %{ids: ~w(one three)}
        |> State.Stop.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == [Enum.at(stops, 0), Enum.at(stops, 2)]
    end

    test "filters by route" do
      stop = %Stop{id: "1"}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{routes: ["route"]}) == [stop]
      assert State.Stop.filter_by(%{routes: ["bad_route"]}) == []
    end

    test "filters by route and direction" do
      stop = %Stop{id: "1"}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", direction_id: 1}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{routes: ["route"], direction_id: 0}) == []
      assert State.Stop.filter_by(%{routes: ["route"], direction_id: 1}) == [stop]
    end

    test "filtering by direction requires also filtering by routes" do
      stop = %Stop{id: "1"}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", direction_id: 1}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{direction_id: 0}) == [stop]
      assert State.Stop.filter_by(%{direction_id: 1}) == [stop]
      assert State.Stop.filter_by(%{routes: ["route"], direction_id: 0}) == []
      assert State.Stop.filter_by(%{routes: ["route"], direction_id: 1}) == [stop]
    end

    test "filters by routes and date" do
      today = Parse.Time.service_date()
      bad_date = %{today | year: today.year - 1}
      stop = %Stop{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", service_id: "service"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{routes: ["route"], date: today}) == [stop]
      assert State.Stop.filter_by(%{routes: ["route"], date: bad_date}) == []
      assert State.Stop.filter_by(%{routes: ["0"], date: today}) == []
    end

    test "filtering by date requires also filtering by routes" do
      today = Parse.Time.service_date()
      bad_date = %{today | year: today.year - 1}
      stop = %Stop{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", service_id: "service"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{routes: ["route"], date: today}) == [stop]
      assert State.Stop.filter_by(%{routes: ["route"], date: bad_date}) == []
      assert State.Stop.filter_by(%{date: today}) == [stop]
      assert State.Stop.filter_by(%{date: bad_date}) == [stop]
    end

    test "filters by latitude and longitude" do
      stop = %Stop{id: "1", latitude: 1, longitude: 2}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.RoutesPatternsAtStop.update!()

      assert State.Stop.filter_by(%{latitude: 3, longitude: 3}) == []
      assert State.Stop.filter_by(%{latitude: 2, longitude: 2}) == []
      assert State.Stop.filter_by(%{latitude: 1, longitude: 2}) == [stop]
    end

    test "filters by latitude, longitude, and radius" do
      stop = %Stop{id: "1", latitude: 1, longitude: 2}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{latitude: 3, longitude: 3, radius: 1}) == []
      assert State.Stop.filter_by(%{latitude: 3, longitude: 3, radius: 3}) == [stop]
    end

    test "filters by route type" do
      stop = %Stop{id: "1"}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1", route_id: "route"}
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      assert State.Stop.filter_by(%{route_types: [0]}) == []
      assert State.Stop.filter_by(%{route_types: [2]}) == [stop]
      assert State.Stop.filter_by(%{route_types: [0, 1, 2]}) == [stop]
    end

    test "filters by location type" do
      stop = %Stop{id: "1", location_type: 0}
      entrance = %Stop{id: "2", location_type: 2}
      State.Stop.new_state([stop, entrance])

      assert State.Stop.filter_by(%{location_types: [0]}) == [stop]
      assert State.Stop.filter_by(%{location_types: [0, 1]}) == [stop]
      assert State.Stop.filter_by(%{location_types: [2]}) == [entrance]
      assert State.Stop.filter_by(%{location_types: [1]}) == []
    end

    test "filters by location type and id" do
      stop = %Stop{id: "1", location_type: 0}
      State.Stop.new_state([stop])

      assert State.Stop.filter_by(%{ids: [stop.id], location_types: [0]}) == [stop]
      assert State.Stop.filter_by(%{ids: [stop.id], location_types: [1, 2]}) == []
    end
  end

  test "last_updated/0" do
    assert %DateTime{} = State.Stop.last_updated()
  end
end
