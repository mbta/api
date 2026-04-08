defmodule ApiWeb.StopEventControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.{Route, Stop, StopEvent, Trip, Vehicle}

  @stop_event1 %StopEvent{
    id: "trip1-route1-v1-1",
    vehicle_id: "v1",
    trip_id: "trip1",
    direction_id: 0,
    route_id: "route1",
    stop_id: "stop1",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:28:06Z],
    departed: ~U[2026-02-24 15:40:46Z]
  }

  @stop_event2 %StopEvent{
    id: "trip2-route2-v2-1",
    vehicle_id: "v2",
    trip_id: "trip2",
    direction_id: 1,
    route_id: "route2",
    stop_id: "stop2",
    start_date: ~D[2026-02-24],
    revenue: :NON_REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:59:03Z],
    departed: nil
  }

  @stop_event3 %StopEvent{
    id: "trip1-route1-v1-2",
    vehicle_id: "v1",
    trip_id: "trip1",
    direction_id: 0,
    route_id: "route1",
    stop_id: "stop2",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 2,
    arrived: ~U[2026-02-24 15:41:26Z],
    departed: ~U[2026-02-24 15:42:13Z]
  }

  @stop_event4 %StopEvent{
    id: "trip2-route1-v2-1",
    vehicle_id: "v2",
    trip_id: "trip2",
    direction_id: 0,
    route_id: "route1",
    stop_id: "stop2",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:59:03Z],
    departed: nil
  }

  @stop_event5 %StopEvent{
    id: "trip2-route1-v2-2",
    vehicle_id: "v2",
    trip_id: "trip2",
    direction_id: 1,
    route_id: "route1",
    stop_id: "stop2",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:59:03Z],
    departed: nil
  }

  @stop_event6 %StopEvent{
    id: "trip3-route2-v3-3",
    vehicle_id: "v3",
    trip_id: "trip3",
    direction_id: 0,
    route_id: "route2",
    stop_id: "stop3",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 16:10:00Z],
    departed: ~U[2026-02-24 16:11:40Z]
  }

  @stop_event7 %StopEvent{
    id: "trip2-route1-1",
    trip_id: "trip2",
    direction_id: 1,
    route_id: "route1",
    stop_id: "stop1",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:59:03Z],
    departed: nil
  }

  @stop_event8 %StopEvent{
    id: "trip3-route1-v3-2",
    vehicle_id: "v3",
    trip_id: "trip3",
    direction_id: 0,
    route_id: "route1",
    stop_id: "stop2",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 16:10:00Z],
    departed: ~U[2026-02-24 16:11:40Z]
  }

  @stop_event9 %StopEvent{
    id: "trip4-route2-v4-1",
    vehicle_id: "v4",
    trip_id: "trip4",
    direction_id: 0,
    route_id: "route2",
    stop_id: "stop1",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 16:26:40Z],
    departed: ~U[2026-02-24 16:30:00Z]
  }

  @stop_event10 %StopEvent{
    id: "trip2-route2-v2-1",
    vehicle_id: "v2",
    trip_id: "trip2",
    direction_id: 1,
    route_id: "route2",
    stop_id: "stop1",
    start_date: ~D[2026-02-24],
    revenue: :REVENUE,
    stop_sequence: 1,
    arrived: ~U[2026-02-24 16:26:40Z],
    departed: ~U[2026-02-24 16:30:00Z]
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp setup_schedule_state do
    State.Trip.new_state([%Trip{id: "trip1", route_id: "route1", direction_id: 0}])
    State.Stop.new_state([%Stop{id: "stop1"}])
    State.Route.new_state([%Route{id: "route1", type: 3}])

    State.RoutePattern.new_state([
      %Model.RoutePattern{id: "route1-_-0", route_id: "route1", direction_id: 0}
    ])

    State.Schedule.new_state([
      %Model.Schedule{
        direction_id: 0,
        route_id: "route1",
        service_id: "service1",
        stop_sequence: 1,
        stop_id: "stop1",
        trip_id: "trip1"
      }
    ])

    State.RoutesPatternsAtStop.update!()
  end

  defp setup_include_state do
    State.Trip.new_state([%Trip{id: "trip1", route_id: "route1", direction_id: 0}])
    State.Stop.new_state([%Stop{id: "stop1"}])
    State.Route.new_state([%Route{id: "route1", type: 3}])
    State.Vehicle.new_state([%Vehicle{id: "v1", latitude: 42.0, longitude: -71.0}])
  end

  describe "index_data/2" do
    test "returns 400 with no filters", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn = get(conn, stop_event_path(conn, :index))

      assert json_response(conn, 400)["errors"] == [
               %{
                 "status" => "400",
                 "code" => "bad_request",
                 "detail" => "At least one filter[] is required."
               }
             ]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      State.StopEvent.new_state([@stop_event1])

      response = get(conn, stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1"}}))
      assert validate_resp_schema(response, schema, "StopEvents")
    end

    test "can filter by trip", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by stop", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event3])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"stop" => "stop2"}}))

      assert [%{"id" => "trip1-route1-v1-2"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"route" => "route1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "returns 400 when only direction_id is provided", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn =
        get(conn, stop_event_path(conn, :index, %{"filter" => %{"direction_id" => "0"}}))

      assert json_response(conn, 400)["errors"] == [
               %{
                 "status" => "400",
                 "code" => "bad_request",
                 "detail" =>
                   "filter[direction_id] must be used in conjunction with another filter[]."
               }
             ]
    end

    test "can filter by vehicle", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"vehicle" => "v1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by multiple parameters simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        @stop_event1,
        @stop_event3,
        @stop_event4,
        @stop_event5,
        @stop_event6,
        @stop_event7,
        @stop_event8,
        @stop_event9,
        @stop_event10
      ])

      for {filters, expected_ids} <- [
            # vehicle + route
            {%{"vehicle" => "v1", "route" => "route1"},
             ["trip1-route1-v1-1", "trip1-route1-v1-2"]},
            # route + direction_id
            {%{"route" => "route1", "direction_id" => "0"},
             [
               "trip1-route1-v1-1",
               "trip1-route1-v1-2",
               "trip2-route1-v2-1",
               "trip3-route1-v3-2"
             ]},
            # trip + stop
            {%{"trip" => "trip1", "stop" => "stop2"}, ["trip1-route1-v1-2"]},
            # route + stop + direction_id
            {%{"route" => "route1", "stop" => "stop1", "direction_id" => "0"},
             ["trip1-route1-v1-1"]},
            # multiple trips + routes + stops
            {%{"trip" => "trip1,trip2", "route" => "route1,route2", "stop" => "stop1"},
             ["trip1-route1-v1-1", "trip2-route1-1", "trip2-route2-v2-1"]},
            # filter by route + opposite direction
            {%{"route" => "route1", "direction_id" => "1"},
             ["trip2-route1-1", "trip2-route1-v2-2"]}
          ] do
        conn = get(conn, stop_event_path(conn, :index, %{"filter" => filters}))
        response_ids = json_response(conn, 200)["data"] |> Enum.map(& &1["id"]) |> Enum.sort()

        assert response_ids == Enum.sort(expected_ids),
               "Failed for filters: #{inspect(filters)}"
      end
    end

    test "pagination works", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event3])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"trip" => "trip1"},
            "page" => %{"limit" => "1", "offset" => "0"}
          })
        )

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert response["links"]["next"]
    end

    test "can include individual resources", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1])
      setup_include_state()

      for {include, expected_type, expected_id} <- [
            {"trip", "trip", "trip1"},
            {"stop", "stop", "stop1"},
            {"route", "route", "route1"},
            {"vehicle", "vehicle", "v1"}
          ] do
        conn =
          get(
            conn,
            stop_event_path(conn, :index, %{
              "filter" => %{"trip" => "trip1"},
              "include" => include
            })
          )

        response = json_response(conn, 200)
        assert [%{"type" => "stop_event"}] = response["data"]
        assert [%{"type" => ^expected_type, "id" => ^expected_id}] = response["included"]
      end
    end

    test "can include multiple resources", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1])
      State.Trip.new_state([%Trip{id: "trip1", route_id: "route1", direction_id: 0}])
      State.Stop.new_state([%Stop{id: "stop1"}])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"trip" => "trip1"},
            "include" => "trip,stop"
          })
        )

      response = json_response(conn, 200)
      assert [%{"type" => "stop_event"}] = response["data"]
      included_types = response["included"] |> Enum.map(& &1["type"]) |> Enum.sort()
      assert ["stop", "trip"] = included_types
    end

    test "returns 400 for invalid include parameter", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"trip" => "trip1"},
            "include" => "invalid_field"
          })
        )

      assert json_response(conn, 400)
    end

    test "can include schedule", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1])
      setup_schedule_state()

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"trip" => "trip1"},
            "include" => "schedule"
          })
        )

      response = json_response(conn, 200)
      assert [%{"type" => "stop_event"}] = response["data"]
      assert [%{"type" => "schedule", "id" => "schedule-trip1-stop1-1"}] = response["included"]
    end
  end

  describe "show_data/2" do
    setup do
      State.StopEvent.new_state([@stop_event1])
      :ok
    end

    test "shows chosen resource", %{conn: conn} do
      conn = get(conn, stop_event_path(conn, :show, @stop_event1.id))
      assert json_response(conn, 200)["data"]["id"] == @stop_event1.id
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, stop_event_path(conn, :show, @stop_event1.id))
      assert validate_resp_schema(response, schema, "StopEvent")
    end

    test "does not show resource when id is nonexistent", %{conn: conn} do
      conn = get(conn, stop_event_path(conn, :show, "nonexistent"))
      assert json_response(conn, 404)
    end

    test "does not allow filtering", %{conn: conn} do
      conn =
        get(conn, stop_event_path(conn, :show, @stop_event1.id, %{"filter[route]" => "route1"}))

      assert json_response(conn, 400)
    end

    test "can include related resources", %{conn: conn} do
      setup_include_state()

      conn =
        get(conn, stop_event_path(conn, :show, @stop_event1.id, %{"include" => "trip,stop"}))

      response = json_response(conn, 200)
      assert response["data"]["id"] == @stop_event1.id
      included_types = response["included"] |> Enum.map(& &1["type"]) |> Enum.sort()
      assert ["stop", "trip"] = included_types
    end
  end

  describe "invalid parameters" do
    test "returns 400 with invalid sort key", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1"}, "sort" => "invalid"})
        )

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["detail"] == "Invalid sort key."
    end

    test "invalid direction_id values return empty results (lenient)", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event3])

      for invalid_value <- ["2", "99", "-1", "abc", "invalid"] do
        conn =
          get(
            conn,
            stop_event_path(conn, :index, %{
              "filter" => %{"trip" => "trip1", "direction_id" => invalid_value}
            })
          )

        response = json_response(conn, 200)

        assert response["data"] == [],
               "Invalid direction_id '#{invalid_value}' should return empty results"
      end
    end

    test "invalid pagination parameters are ignored (lenient)", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2, @stop_event3])

      # Test cases: all should return 2 results (trip1 has 2 events)
      for {param, value} <- [
            {"offset", "-1"},
            {"offset", "abc"},
            {"limit", "0"},
            {"limit", "-5"},
            {"limit", "xyz"}
          ] do
        conn =
          get(
            conn,
            stop_event_path(conn, :index, %{
              "filter" => %{"trip" => "trip1"},
              "page" => %{param => value}
            })
          )

        response = json_response(conn, 200)

        assert length(response["data"]) == 2,
               "Invalid #{param}=#{value} should be ignored and return all results"
      end
    end

    test "empty or whitespace filter values return empty results", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2])

      for filter_value <- ["", "   "] do
        conn =
          get(conn, stop_event_path(conn, :index, %{"filter" => %{"trip" => filter_value}}))

        response = json_response(conn, 200)
        assert response["data"] == []
      end
    end

    test "valid pagination with offset and limit works correctly", %{conn: conn} do
      State.StopEvent.new_state([@stop_event1, @stop_event2, @stop_event3, @stop_event4])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"route" => "route1"},
            "page" => %{"offset" => "1", "limit" => "2"}
          })
        )

      response = json_response(conn, 200)
      assert length(response["data"]) == 2
    end
  end
end
