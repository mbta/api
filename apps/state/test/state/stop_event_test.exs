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
        stop_sequence: 1,
        arrived: ~U[2026-02-24 15:28:06Z],
        departed: ~U[2026-02-24 15:40:46Z]
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
        stop_sequence: 2,
        arrived: ~U[2026-02-24 15:41:26Z],
        departed: ~U[2026-02-24 15:42:13Z]
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
        stop_sequence: 1,
        arrived: ~U[2026-02-24 15:59:03Z],
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
        stop_sequence: 1,
        arrived: ~U[2026-02-24 16:10:00Z],
        departed: ~U[2026-02-24 16:11:40Z]
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

  describe "filter_by/2 with pagination" do
    setup do
      events =
        for i <- 1..10 do
          %StopEvent{
            id: "trip#{i}-route1-v1-#{i}",
            vehicle_id: "v1",
            start_date: ~D[2026-02-24],
            trip_id: "trip#{i}",
            direction_id: rem(i, 2),
            route_id: "route1",
            start_time: "10:00:00",
            revenue: :REVENUE,
            stop_id: "stop#{i}",
            stop_sequence: i,
            arrived: DateTime.add(~U[2026-02-24 15:28:06Z], i * 100, :second),
            departed: DateTime.add(~U[2026-02-24 15:40:46Z], i * 100, :second)
          }
        end

      State.StopEvent.new_state(events)
      {:ok, %{events: events}}
    end

    test "supports limit option" do
      {result, _pagination} = filter_by(%{route_ids: ["route1"]}, limit: 3)
      assert length(result) == 3
    end

    test "supports offset option" do
      all_results = filter_by(%{route_ids: ["route1"]})
      {offset_results, _pagination} = filter_by(%{route_ids: ["route1"]}, offset: 2, limit: 20)

      assert length(offset_results) == length(all_results) - 2
    end

    test "supports limit and offset together" do
      {result, _pagination} = filter_by(%{route_ids: ["route1"]}, limit: 2, offset: 3)
      assert length(result) == 2
    end

    test "supports order_by option" do
      # Order by stop_sequence ascending
      {result, _pagination} =
        filter_by(%{route_ids: ["route1"]}, order_by: {:stop_sequence, :asc}, limit: 20)

      assert length(result) == 10
      assert hd(result).stop_sequence == 1
      assert List.last(result).stop_sequence == 10
    end

    test "combines pagination with filtering" do
      # Filter by direction_id 0 (odd numbered trips: 1,3,5,7,9), limit 2
      {result, _pagination} = filter_by(%{direction_id: 0}, limit: 2)
      assert length(result) == 2
      assert Enum.all?(result, fn e -> e.direction_id == 0 end)
    end
  end

  describe "filter_by/2 selectivity optimization" do
    setup do
      # Create data where vehicle_id is most selective (1 match),
      # trip_id is medium (3 matches), route_id is least selective (5 matches)
      events = [
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          route_id: "route1",
          stop_id: "stop1",
          direction_id: 0,
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: ~U[2026-02-24 15:28:06Z],
          departed: ~U[2026-02-24 15:40:46Z]
        },
        %StopEvent{
          id: "trip1-route1-v2-2",
          vehicle_id: "v2",
          trip_id: "trip1",
          route_id: "route1",
          stop_id: "stop2",
          direction_id: 0,
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 2,
          arrived: ~U[2026-02-24 15:29:46Z],
          departed: ~U[2026-02-24 15:42:26Z]
        },
        %StopEvent{
          id: "trip1-route1-v3-3",
          vehicle_id: "v3",
          trip_id: "trip1",
          route_id: "route1",
          stop_id: "stop3",
          direction_id: 0,
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 3,
          arrived: ~U[2026-02-24 15:31:26Z],
          departed: ~U[2026-02-24 15:44:06Z]
        },
        %StopEvent{
          id: "trip2-route1-v4-1",
          vehicle_id: "v4",
          trip_id: "trip2",
          route_id: "route1",
          stop_id: "stop1",
          direction_id: 1,
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: ~U[2026-02-24 15:53:20Z],
          departed: ~U[2026-02-24 15:55:00Z]
        },
        %StopEvent{
          id: "trip2-route1-v5-2",
          vehicle_id: "v5",
          trip_id: "trip2",
          route_id: "route1",
          stop_id: "stop2",
          direction_id: 1,
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 2,
          arrived: ~U[2026-02-24 15:55:00Z],
          departed: ~U[2026-02-24 15:56:40Z]
        }
      ]

      State.StopEvent.new_state(events)
      {:ok, %{}}
    end

    test "selects most selective filter when multiple filters provided" do
      # vehicle_id (1 match) should be chosen over route_id (5 matches)
      result = filter_by(%{vehicle_ids: ["v1"], route_ids: ["route1"]})
      assert length(result) == 1
      assert hd(result).vehicle_id == "v1"
    end

    test "handles single filter efficiently without MapSet overhead" do
      # Single filter should work without creating MapSets
      result = filter_by(%{vehicle_ids: ["v1"]})
      assert length(result) == 1
      assert hd(result).vehicle_id == "v1"
    end

    test "handles single filter with direction_id" do
      # Single indexed filter + direction should work efficiently
      result = filter_by(%{vehicle_ids: ["v1"], direction_id: 0})
      assert length(result) == 1
      assert hd(result).vehicle_id == "v1"
      assert hd(result).direction_id == 0
    end

    test "handles direction_id only filter" do
      # Direction only should still work (full scan)
      result = filter_by(%{direction_id: 0})
      assert length(result) == 3
      assert Enum.all?(result, fn e -> e.direction_id == 0 end)
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
        stop_sequence: 1,
        arrived: ~U[2026-02-24 15:28:06Z],
        departed: ~U[2026-02-24 15:40:46Z]
      }

      State.StopEvent.new_state([stop_event])

      assert by_id("trip1-route1-v1-1") == stop_event
    end

    test "returns nil for non-existent id" do
      assert by_id("nonexistent") == nil
    end
  end
end
