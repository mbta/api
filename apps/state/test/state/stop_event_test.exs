defmodule State.StopEventTest do
  use ExUnit.Case

  alias Model.StopEvent
  import State.StopEvent

  describe "filter_by/1" do
    setup do
      stop_event1 = %StopEvent{
        id: "trip1-route1-v1-1",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        start_time: "10:00:00",
        revenue: :REVENUE,
        stop_id: "stop1",
        current_stop_sequence: 1,
        arrived: 1_771_966_486,
        departed: 1_771_967_246
      }

      stop_event2 = %StopEvent{
        id: "trip1-route1-v1-2",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        start_time: "10:00:00",
        revenue: :REVENUE,
        stop_id: "stop2",
        current_stop_sequence: 2,
        arrived: 1_771_967_286,
        departed: 1_771_967_333
      }

      stop_event3 = %StopEvent{
        id: "trip2-route2-v2-3",
        vehicle_id: "v2",
        start_date: ~D[2026-02-24],
        trip_id: "trip2",
        direction_id: 1,
        route_id: "route2",
        start_time: "11:00:00",
        revenue: :NON_REVENUE,
        stop_id: "stop3",
        current_stop_sequence: 1,
        arrived: 1_771_968_343,
        departed: nil
      }

      State.StopEvent.new_state([stop_event1, stop_event2, stop_event3])

      {:ok, %{event1: stop_event1, event2: stop_event2, event3: stop_event3}}
    end

    test "returns all events with empty filters", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{})
      assert length(result) == 3
      assert e1 in result
      assert e2 in result
      assert e3 in result
    end

    test "filters by trip_id", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{trip_ids: ["trip1"]})
      assert length(result) == 2
      assert e1 in result
      assert e2 in result
      refute e3 in result
    end

    test "filters by multiple trip_ids", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{trip_ids: ["trip1", "trip2"]})
      assert length(result) == 3
      assert e1 in result
      assert e2 in result
      assert e3 in result
    end

    test "filters by stop_id", %{event1: e1, event2: _e2} do
      result = filter_by(%{stop_ids: ["stop1"]})
      assert result == [e1]
    end

    test "filters by multiple stop_ids", %{event1: e1, event3: e3} do
      result = filter_by(%{stop_ids: ["stop1", "stop3"]})
      assert length(result) == 2
      assert e1 in result
      assert e3 in result
    end

    test "filters by route_id", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{route_ids: ["route1"]})
      assert length(result) == 2
      assert e1 in result
      assert e2 in result
      refute e3 in result
    end

    test "filters by multiple route_ids", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{route_ids: ["route1", "route2"]})
      assert length(result) == 3
      assert e1 in result
      assert e2 in result
      assert e3 in result
    end

    test "filters by vehicle_id", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{vehicle_ids: ["v1"]})
      assert length(result) == 2
      assert e1 in result
      assert e2 in result
      refute e3 in result
    end

    test "filters by multiple vehicle_ids", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{vehicle_ids: ["v1", "v2"]})
      assert length(result) == 3
      assert e1 in result
      assert e2 in result
      assert e3 in result
    end

    test "filters by direction_id", %{event1: e1, event2: e2, event3: e3} do
      result = filter_by(%{direction_id: 0})
      assert length(result) == 2
      assert e1 in result
      assert e2 in result
      refute e3 in result

      result = filter_by(%{direction_id: 1})
      assert result == [e3]
    end

    test "filters by trip_id and stop_id", %{event1: e1} do
      result = filter_by(%{trip_ids: ["trip1"], stop_ids: ["stop1"]})
      assert result == [e1]
    end

    test "filters by route_id and direction_id", %{event1: e1, event2: e2} do
      result = filter_by(%{route_ids: ["route1"], direction_id: 0})
      assert length(result) == 2
      assert e1 in result
      assert e2 in result
    end

    test "filters by trip_id, stop_id, and direction_id simultaneously", %{event1: e1} do
      result = filter_by(%{trip_ids: ["trip1"], stop_ids: ["stop1"], direction_id: 0})
      assert result == [e1]
    end

    test "filters by route_id, stop_id, and direction_id simultaneously", %{event1: e1} do
      result = filter_by(%{route_ids: ["route1"], stop_ids: ["stop1"], direction_id: 0})
      assert result == [e1]
    end

    test "filters by multiple values across all filter types" do
      # Add more test data for this test
      stop_event4 = %StopEvent{
        id: "trip2-route1-v2-1",
        vehicle_id: "v2",
        start_date: ~D[2026-02-24],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route1",
        start_time: "12:00:00",
        revenue: :REVENUE,
        stop_id: "stop1",
        current_stop_sequence: 1,
        arrived: 1_771_969_000,
        departed: 1_771_969_100
      }

      all_events = State.StopEvent.all()
      State.StopEvent.new_state(all_events ++ [stop_event4])

      # Filter for trip1 OR trip2, route1, stop1, direction 0
      result =
        filter_by(%{
          trip_ids: ["trip1", "trip2"],
          route_ids: ["route1"],
          stop_ids: ["stop1"],
          direction_id: 0
        })

      # Should return both trip1-route1-stop1 and trip2-route1-stop1
      assert length(result) == 2
      assert Enum.all?(result, fn e -> e.route_id == "route1" end)
      assert Enum.all?(result, fn e -> e.stop_id == "stop1" end)
      assert Enum.all?(result, fn e -> e.direction_id == 0 end)
      assert Enum.all?(result, fn e -> e.trip_id in ["trip1", "trip2"] end)
    end

    test "returns empty when combining filters that match no records", %{event1: _e1, event2: _e2} do
      # event1 and event2 both have route1, but only event1 has stop1
      # Filtering for route1, stop2, and direction_id 1 should return nothing
      result = filter_by(%{route_ids: ["route1"], stop_ids: ["stop2"], direction_id: 1})
      assert result == []
    end

    test "returns empty list for non-matching filters" do
      assert filter_by(%{trip_ids: ["nonexistent"]}) == []
      assert filter_by(%{stop_ids: ["nonexistent"]}) == []
      assert filter_by(%{route_ids: ["nonexistent"]}) == []
      assert filter_by(%{direction_id: 2}) == []
    end

    test "returns empty list for empty id lists" do
      assert filter_by(%{trip_ids: []}) == []
      assert filter_by(%{stop_ids: []}) == []
      assert filter_by(%{route_ids: []}) == []
    end
  end

  describe "by_id/1" do
    test "returns stop event by id" do
      stop_event = %StopEvent{
        id: "trip1-route1-v1-1",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        start_time: "10:00:00",
        revenue: :REVENUE,
        stop_id: "stop1",
        current_stop_sequence: 1,
        arrived: 1_771_966_486,
        departed: 1_771_967_246
      }

      State.StopEvent.new_state([stop_event])

      assert by_id("trip1-route1-v1-1") == stop_event
    end

    test "returns nil for non-existent id" do
      assert by_id("nonexistent") == nil
    end
  end
end
