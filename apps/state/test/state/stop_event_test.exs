defmodule State.StopEventTest do
  use ExUnit.Case

  alias Model.StopEvent
  import State.StopEvent

  # Disable automatic eviction by default for all tests except those explicitly testing eviction
  setup do
    Application.put_env(:state, State.StopEvent, retention_seconds: 999_999_999)
    on_exit(fn -> Application.delete_env(:state, State.StopEvent) end)
    :ok
  end

  describe "filter_by/1" do
    setup do
      stop_event1 = %StopEvent{
        id: "trip1-route1-v1-1",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
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
        revenue: :NON_REVENUE,
        stop_id: "stop3",
        stop_sequence: 1,
        arrived: ~U[2026-02-24 15:59:03Z],
        departed: nil
      }

      State.StopEvent.new_state([stop_event1, stop_event2, stop_event3])

      {:ok, %{event1: stop_event1, event2: stop_event2, event3: stop_event3}}
    end

    test "returns no events no filters provided", %{event1: _e1, event2: _e2, event3: _e3} do
      result = filter_by(%{})
      assert result == []
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
      stop_event4 = %StopEvent{
        id: "trip2-route1-v2-1",
        vehicle_id: "v2",
        start_date: ~D[2026-02-24],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: ~U[2026-02-24 16:10:00Z],
        departed: ~U[2026-02-24 16:11:40Z]
      }

      all_events = State.StopEvent.all()
      State.StopEvent.new_state(all_events ++ [stop_event4])

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

    test "handles single filter efficiently" do
      result = filter_by(%{vehicle_ids: ["v1"]})
      assert length(result) == 1
      assert hd(result).vehicle_id == "v1"
    end

    test "handles single filter with direction_id" do
      result = filter_by(%{vehicle_ids: ["v1"], direction_id: 0})
      assert length(result) == 1
      assert hd(result).vehicle_id == "v1"
      assert hd(result).direction_id == 0
    end

    test "handles direction_id only filter" do
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

  describe "partial updates with timestamps" do
    setup do
      stop_event1 = %StopEvent{
        id: "trip1-route1-v1-1",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
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
        revenue: :REVENUE,
        stop_id: "stop2",
        stop_sequence: 2,
        arrived: ~U[2026-02-24 15:41:26Z],
        departed: ~U[2026-02-24 15:42:13Z]
      }

      State.StopEvent.new_state([stop_event1, stop_event2])

      {:ok, %{event1: stop_event1, event2: stop_event2}}
    end

    test "partial update only affects records with matching keys", %{event1: _e1, event2: _e2} do
      # Initial state already set up with 2 events
      assert State.StopEvent.size() == 2

      # Partial update - replace event with id trip1-route1-v1-1 and add new event
      updated_event = %StopEvent{
        id: "trip1-route1-v1-1",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: ~U[2026-02-24 15:28:06Z],
        departed: ~U[2026-02-24 15:41:00Z]
      }

      new_event = %StopEvent{
        id: "trip1-route1-v1-3",
        vehicle_id: "v1",
        start_date: ~D[2026-02-24],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop3",
        stop_sequence: 3,
        arrived: ~U[2026-02-24 15:43:00Z],
        departed: ~U[2026-02-24 15:44:00Z]
      }

      State.StopEvent.new_state({:partial, [updated_event, new_event]})

      # Should now have 3 events
      assert State.StopEvent.size() == 3

      # Verify the update was applied
      result = by_id("trip1-route1-v1-1")
      assert result.departed == ~U[2026-02-24 15:41:00Z]

      # Verify the new event was added
      result = by_id("trip1-route1-v1-3")
      assert result.stop_sequence == 3

      # Verify the unchanged event is still there
      result = by_id("trip1-route1-v1-2")
      assert result.departed == ~U[2026-02-24 15:42:13Z]
    end

    test "accepts NDJSON string with timestamp filtering" do
      # Create initial state with old events
      ndjson_old = """
      {"id":"old-event-1","timestamp":1771968300,"start_date":"20260224","trip_id":"trip1","vehicle_id":"v1","direction_id":0,"route_id":"route1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"old-event-2","timestamp":1771968340,"start_date":"20260224","trip_id":"trip2","vehicle_id":"v2","direction_id":0,"route_id":"route2","revenue":true,"stop_id":"stop2","stop_sequence":2,"arrived":1771966486,"departed":1771967246}
      """

      gzipped_old = :zlib.gzip(ndjson_old)
      State.StopEvent.new_state(gzipped_old)
      assert State.StopEvent.size() == 2

      # Verify the timestamps were stored
      event1 = by_id("old-event-1")
      assert event1.timestamp == 1_771_968_300

      # Send an update with both old and new events
      # The automatic timestamp filtering should only process the new ones
      ndjson_update = """
      {"id":"old-event-1","timestamp":1771968300,"start_date":"20260224","trip_id":"trip1","vehicle_id":"v1","direction_id":0,"route_id":"route1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"old-event-2","timestamp":1771968340,"start_date":"20260224","trip_id":"trip2","vehicle_id":"v2","direction_id":0,"route_id":"route2","revenue":true,"stop_id":"stop2","stop_sequence":2,"arrived":1771966486,"departed":1771967246}
      {"id":"new-event-1","timestamp":1771968350,"start_date":"20260224","trip_id":"trip3","vehicle_id":"v3","direction_id":0,"route_id":"route3","revenue":true,"stop_id":"stop3","stop_sequence":3,"arrived":1771966486,"departed":1771967246}
      {"id":"new-event-2","timestamp":1771968360,"start_date":"20260224","trip_id":"trip4","vehicle_id":"v4","direction_id":0,"route_id":"route4","revenue":true,"stop_id":"stop4","stop_sequence":4,"arrived":1771966486,"departed":1771967246}
      """

      gzipped_update = :zlib.gzip(ndjson_update)

      # This should automatically use timestamp filtering and only add the 2 new events
      State.StopEvent.new_state(gzipped_update)

      # Should have 4 events total (2 old + 2 new)
      assert State.StopEvent.size() == 4

      # Verify the new events were added
      new_event1 = by_id("new-event-1")
      assert new_event1.timestamp == 1_771_968_350

      new_event2 = by_id("new-event-2")
      assert new_event2.timestamp == 1_771_968_360
    end

    test "timestamp filtering works correctly on subsequent updates" do
      # Initial state
      ndjson1 = """
      {"id":"event-1","timestamp":1771968300,"start_date":"20260224","trip_id":"trip1","vehicle_id":"v1","direction_id":0,"route_id":"route1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      State.StopEvent.new_state(:zlib.gzip(ndjson1))
      assert State.StopEvent.size() == 1

      # Second update - should filter based on timestamp 1771968300
      ndjson2 = """
      {"id":"event-1","timestamp":1771968300,"start_date":"20260224","trip_id":"trip1","vehicle_id":"v1","direction_id":0,"route_id":"route1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"event-2","timestamp":1771968350,"start_date":"20260224","trip_id":"trip2","vehicle_id":"v2","direction_id":0,"route_id":"route2","revenue":true,"stop_id":"stop2","stop_sequence":2,"arrived":1771966486,"departed":1771967246}
      """

      State.StopEvent.new_state(:zlib.gzip(ndjson2))
      assert State.StopEvent.size() == 2

      # Third update - should filter based on timestamp 1771968350
      ndjson3 = """
      {"id":"event-1","timestamp":1771968300,"start_date":"20260224","trip_id":"trip1","vehicle_id":"v1","direction_id":0,"route_id":"route1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"event-2","timestamp":1771968350,"start_date":"20260224","trip_id":"trip2","vehicle_id":"v2","direction_id":0,"route_id":"route2","revenue":true,"stop_id":"stop2","stop_sequence":2,"arrived":1771966486,"departed":1771967246}
      {"id":"event-3","timestamp":1771968400,"start_date":"20260224","trip_id":"trip3","vehicle_id":"v3","direction_id":0,"route_id":"route3","revenue":true,"stop_id":"stop3","stop_sequence":3,"arrived":1771966486,"departed":1771967246}
      """

      State.StopEvent.new_state(:zlib.gzip(ndjson3))
      assert State.StopEvent.size() == 3

      # Verify all events are present
      assert by_id("event-1").timestamp == 1_771_968_300
      assert by_id("event-2").timestamp == 1_771_968_350
      assert by_id("event-3").timestamp == 1_771_968_400
    end
  end

  describe "evicting old records" do
    # Tests in this describe block use the global setup that disables eviction

    test "evicts records older than the configured retention period" do
      now = System.system_time(:second)
      two_hours_ago = now - 7200
      three_hours_ago = now - 10_800
      one_hour_ago = now - 3600

      old_event = %StopEvent{
        id: "old-event",
        vehicle_id: "v1",
        start_date: ~D[2026-08-05],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: three_hours_ago
      }

      borderline_event = %StopEvent{
        id: "borderline-event",
        vehicle_id: "v2",
        start_date: ~D[2026-08-05],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route2",
        revenue: :REVENUE,
        stop_id: "stop2",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: two_hours_ago
      }

      recent_event = %StopEvent{
        id: "recent-event",
        vehicle_id: "v3",
        start_date: ~D[2026-08-05],
        trip_id: "trip3",
        direction_id: 0,
        route_id: "route3",
        revenue: :REVENUE,
        stop_id: "stop3",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: one_hour_ago
      }

      State.StopEvent.new_state([old_event, borderline_event, recent_event])
      assert State.StopEvent.size() == 3

      # Trigger eviction with 2-hour retention (7200 seconds)
      State.StopEvent.evict_old_records(7200)

      # Old event should be evicted, borderline is exactly at boundary (should be kept),
      # recent should remain
      assert State.StopEvent.size() == 2
      assert is_nil(by_id("old-event"))
      refute is_nil(by_id("borderline-event"))
      refute is_nil(by_id("recent-event"))
    end

    test "evicts records using custom retention period" do
      now = System.system_time(:second)
      thirty_minutes_ago = now - 1800
      forty_five_minutes_ago = now - 2700

      old_event = %StopEvent{
        id: "old-event",
        vehicle_id: "v1",
        start_date: ~D[2026-08-05],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: forty_five_minutes_ago
      }

      recent_event = %StopEvent{
        id: "recent-event",
        vehicle_id: "v2",
        start_date: ~D[2026-08-05],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route2",
        revenue: :REVENUE,
        stop_id: "stop2",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: thirty_minutes_ago
      }

      State.StopEvent.new_state([old_event, recent_event])
      assert State.StopEvent.size() == 2

      # Evict with 40 minute retention (2400 seconds)
      State.StopEvent.evict_old_records(2400)

      assert State.StopEvent.size() == 1
      assert is_nil(by_id("old-event"))
      refute is_nil(by_id("recent-event"))
    end

    test "handles records without timestamps gracefully" do
      now = System.system_time(:second)
      one_hour_ago = now - 3600

      event_with_timestamp = %StopEvent{
        id: "with-timestamp",
        vehicle_id: "v1",
        start_date: ~D[2026-08-05],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: one_hour_ago
      }

      event_without_timestamp = %StopEvent{
        id: "without-timestamp",
        vehicle_id: "v2",
        start_date: ~D[2026-08-05],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route2",
        revenue: :REVENUE,
        stop_id: "stop2",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: nil
      }

      State.StopEvent.new_state([event_with_timestamp, event_without_timestamp])
      assert State.StopEvent.size() == 2

      # Eviction should not crash on nil timestamps
      State.StopEvent.evict_old_records(7200)

      # Both should remain (one is recent, one has no timestamp to compare)
      assert State.StopEvent.size() == 2
    end
  end

  describe "automatic eviction on new_state" do
    test "evicts old records automatically when configured" do
      # Set a short retention period for this test
      Application.put_env(:state, State.StopEvent, retention_seconds: 7200)
      on_exit(fn -> Application.delete_env(:state, State.StopEvent) end)

      now = System.system_time(:second)
      three_hours_ago = now - 10_800
      one_hour_ago = now - 3600

      old_event = %StopEvent{
        id: "old-event",
        vehicle_id: "v1",
        start_date: ~D[2026-08-05],
        trip_id: "trip1",
        direction_id: 0,
        route_id: "route1",
        revenue: :REVENUE,
        stop_id: "stop1",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: three_hours_ago
      }

      State.StopEvent.new_state([old_event])
      # Old event is automatically evicted by post_commit_hook
      assert State.StopEvent.size() == 0

      # Add a new event - should trigger automatic eviction
      recent_event = %StopEvent{
        id: "recent-event",
        vehicle_id: "v2",
        start_date: ~D[2026-08-05],
        trip_id: "trip2",
        direction_id: 0,
        route_id: "route2",
        revenue: :REVENUE,
        stop_id: "stop2",
        stop_sequence: 1,
        arrived: nil,
        departed: nil,
        timestamp: one_hour_ago
      }

      State.StopEvent.new_state([recent_event])

      # Recent event should be kept
      assert by_id("recent-event") != nil
      assert State.StopEvent.size() == 1
    end
  end
end
