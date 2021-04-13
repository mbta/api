defmodule ConnectingStopsTest do
  use ExUnit.Case
  alias Model.{Schedule, Stop, Trip}
  alias State.ConnectingStops

  defp new_state(stops) do
    # Convenience for testing with stops alone: put each stop on its own pattern
    patterns =
      stops
      |> Enum.with_index()
      |> Enum.map(fn {%{id: stop_id}, index} -> {"pattern#{index}", 0, nil, [stop_id]} end)

    new_state(stops, patterns)
  end

  defp new_state(stops, patterns) do
    # Convenience for defining trips and schedules that serve the given stops
    {trips, schedules} =
      patterns
      |> Enum.with_index()
      |> Enum.map(fn {{route_pattern_id, direction_id, route_type, stop_ids}, index} ->
        trip_id = "trip#{index}"

        {
          %Trip{
            id: trip_id,
            route_pattern_id: route_pattern_id,
            direction_id: direction_id,
            route_type: route_type
          },
          Enum.map(stop_ids, fn stop_id -> %Schedule{trip_id: trip_id, stop_id: stop_id} end)
        }
      end)
      |> Enum.unzip()

    new_state(stops, trips, List.flatten(schedules))
  end

  defp new_state(stops, trips, schedules, wait_for_update? \\ true) do
    State.Stop.new_state(stops)
    State.Trip.new_state(trips)
    State.Schedule.new_state(schedules)

    if wait_for_update? do
      State.RoutesPatternsAtStop.update!()
      ConnectingStops.update!()
    end
  end

  describe "for_stop_id/1" do
    defp connecting_stop_ids(stop_id) do
      stop_id |> ConnectingStops.for_stop_id() |> Enum.map(& &1.id) |> Enum.sort()
    end

    test "returns no connections if there is no such stop" do
      new_state([])

      assert connecting_stop_ids("parent") == []
    end

    test "returns no connections if there are no nearby stops" do
      new_state([%Stop{id: "parent", location_type: 1, latitude: 0, longitude: 0}])

      assert connecting_stop_ids("parent") == []
    end

    test "connects a parent station with stops close to its entrances" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 2, longitude: 0},
        %Stop{id: "e1", location_type: 2, parent_station: "parent", latitude: 1, longitude: 0},
        %Stop{id: "e2", location_type: 2, parent_station: "parent", latitude: 3, longitude: 0},
        %Stop{id: "near1", location_type: 0, latitude: 1.0001, longitude: 0},
        %Stop{id: "near2", location_type: 0, latitude: 3.0001, longitude: 0},
        %Stop{id: "far", location_type: 0, latitude: 1.01, longitude: 0}
      ])

      assert connecting_stop_ids("parent") == ["near1", "near2"]
      assert connecting_stop_ids("near1") == ["near2", "parent"]
      assert connecting_stop_ids("near2") == ["near1", "parent"]
    end

    test "does not connect standalone stops close to each other" do
      new_state([
        %Stop{id: "stop1", location_type: 0, latitude: 1, longitude: 0},
        %Stop{id: "stop2", location_type: 0, latitude: 1.0001, longitude: 0}
      ])

      assert connecting_stop_ids("stop1") == []
      assert connecting_stop_ids("stop2") == []
    end

    test "only connects parent stations to stops without a parent station" do
      new_state([
        %Stop{id: "parent1", location_type: 1, latitude: 2, longitude: 0},
        %Stop{id: "e1", location_type: 2, parent_station: "parent1", latitude: 1, longitude: 0},
        %Stop{
          id: "child1",
          location_type: 0,
          parent_station: "parent1",
          latitude: 1.0001,
          longitude: 0
        },
        %Stop{id: "parent2", location_type: 1, latitude: 0, longitude: 0},
        %Stop{
          id: "child2",
          location_type: 0,
          parent_station: "parent2",
          latitude: 0.9999,
          longitude: 0
        },
        %Stop{id: "near", location_type: 0, latitude: 1.0001, longitude: 0}
      ])

      assert connecting_stop_ids("parent1") == ["near"]
    end

    test "uses the parent location to determine closeness if it has no entrances" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 2, longitude: 0},
        %Stop{id: "near", location_type: 0, latitude: 2.0001, longitude: 0},
        %Stop{id: "far", location_type: 0, latitude: 3, longitude: 0}
      ])

      assert connecting_stop_ids("parent") == ["near"]
    end

    test "does not consider the parent location if it has entrances" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 2, longitude: 0},
        %Stop{id: "e1", location_type: 2, parent_station: "parent", latitude: 1, longitude: 0},
        %Stop{id: "far", location_type: 0, latitude: 2.0001, longitude: 0}
      ])

      assert connecting_stop_ids("parent") == []
    end

    test "connects stops to multiple close parent stations" do
      new_state([
        %Stop{id: "parent1", location_type: 1, latitude: 1.0001, longitude: 0},
        %Stop{id: "parent2", location_type: 1, latitude: 1.0003, longitude: 0},
        %Stop{id: "near", location_type: 0, latitude: 1.0002, longitude: 0}
      ])

      assert connecting_stop_ids("near") == ["parent1", "parent2"]
      assert connecting_stop_ids("parent1") == ["near"]
      assert connecting_stop_ids("parent2") == ["near"]
    end

    test "does not create duplicate connections when a stop is close to multiple entrances" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 2, longitude: 0},
        %Stop{id: "e1", location_type: 2, parent_station: "parent", latitude: 1, longitude: 0},
        %Stop{
          id: "e2",
          location_type: 2,
          parent_station: "parent",
          latitude: 1.0002,
          longitude: 0
        },
        %Stop{id: "near", location_type: 0, latitude: 1.0001, longitude: 0}
      ])

      assert connecting_stop_ids("parent") == ["near"]
      assert connecting_stop_ids("near") == ["parent"]
    end

    test "connects only the closest stop of several that share the same route patterns" do
      new_state(
        [
          %Stop{id: "parent", location_type: 1, latitude: 2, longitude: 0},
          %Stop{id: "e1", location_type: 2, parent_station: "parent", latitude: 1, longitude: 0},
          %Stop{id: "e2", location_type: 2, parent_station: "parent", latitude: 3, longitude: 0},
          %Stop{id: "near1", location_type: 0, latitude: 1.0001, longitude: 0},
          %Stop{id: "near2", location_type: 0, latitude: 1.0002, longitude: 0},
          %Stop{id: "near3", location_type: 0, latitude: 3.0003, longitude: 0}
        ],
        [
          {"pattern1", 0, nil, ["near1", "near2", "near3"]},
          {"pattern2", 1, nil, ["near3", "near2", "near1"]}
        ]
      )

      # closer to the overall location of the parent
      assert connecting_stop_ids("parent") == ["near2"]
    end

    test "connects stops even if they are only served by 'ignored' trips" do
      new_state(
        [
          %Stop{id: "parent", location_type: 1, latitude: 1, longitude: 0},
          %Stop{id: "shuttle", location_type: 0, latitude: 1.0001, longitude: 0}
        ],
        # trips with a route type are normally "ignored" w.r.t. patterns (see `State.Helpers`)
        [{"pattern", 0, 3, ["shuttle"]}]
      )

      assert connecting_stop_ids("parent") == ["shuttle"]
    end

    test "allows overrides to add a connection that wouldn't otherwise exist" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 1, longitude: 0},
        %Stop{id: "near", location_type: 0, latitude: 1.0001, longitude: 0},
        %Stop{id: "far", location_type: 0, latitude: 2, longitude: 0}
      ])

      ConnectingStops.update!(%{"parent" => %{add: ["far"]}})

      assert connecting_stop_ids("parent") == ["far", "near"]
      assert connecting_stop_ids("far") == ["near", "parent"]
    end

    test "allows overrides to remove a connection that would otherwise exist" do
      new_state([
        %Stop{id: "parent", location_type: 1, latitude: 1, longitude: 0},
        %Stop{id: "near1", location_type: 0, latitude: 1.0001, longitude: 0},
        %Stop{id: "near2", location_type: 0, latitude: 1.0002, longitude: 0}
      ])

      ConnectingStops.update!(%{"parent" => %{remove: ["near1"]}})

      assert connecting_stop_ids("parent") == ["near2"]
      assert connecting_stop_ids("near2") == ["parent"]
      assert connecting_stop_ids("near1") == []
    end
  end

  describe "inspect/0" do
    test "allows inspecting all connections by parent station" do
      new_state(
        [
          %Stop{id: "parent", name: "Parent", location_type: 1, latitude: 2, longitude: 0},
          %Stop{id: "e1", location_type: 2, parent_station: "parent", latitude: 1, longitude: 0},
          %Stop{id: "e2", location_type: 2, parent_station: "parent", latitude: 3, longitude: 0},
          %Stop{id: "near1", name: "Near 1", location_type: 0, latitude: 1.0001, longitude: 0},
          %Stop{id: "near2", name: "Near 2", location_type: 0, latitude: 3.0003, longitude: 0}
        ],
        [
          {"pattern0", 0, nil, ["parent"]},
          {"pattern1", 0, nil, ["near1"]},
          {"pattern2", 0, nil, ["near2"]}
        ]
      )

      assert ConnectingStops.inspect() == [
               [
                 {"parent", "Parent", ["pattern0"]},
                 {"near1", "Near 1", ["pattern1"]},
                 {"near2", "Near 2", ["pattern2"]}
               ]
             ]
    end
  end

  describe "server" do
    @stops [
      %Stop{id: "parent", location_type: 1, latitude: 1, longitude: 0},
      %Stop{id: "child", location_type: 0, parent_station: "parent"},
      %Stop{id: "enter", location_type: 2, parent_station: "parent", latitude: 2, longitude: 0},
      %Stop{id: "near", location_type: 0, latitude: 2, longitude: 0}
    ]
    @trips [
      %Trip{id: "trip1", route_pattern_id: "pattern1", direction_id: 0},
      %Trip{id: "trip2", route_pattern_id: "pattern2", direction_id: 0}
    ]
    @schedules [
      %Schedule{trip_id: "trip1", stop_id: "child"},
      %Schedule{trip_id: "trip2", stop_id: "near"}
    ]

    setup do
      Events.subscribe({:new_state, ConnectingStops})
    end

    test "updates and publishes an event when its sources update" do
      new_state(@stops, @trips, @schedules, false)
      assert_receive({:event, {:new_state, ConnectingStops}, 2, _})
    end

    test "restarts and recovers after stopping" do
      new_state(@stops, @trips, @schedules, false)
      assert_receive({:event, _, 2, _})

      GenServer.stop(ConnectingStops)

      assert_receive({:event, _, 0, _})
      assert_receive({:event, _, 2, _})
    end
  end
end
