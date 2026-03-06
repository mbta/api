defmodule ApiWeb.StopEventControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.StopEvent

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "returns 400 with no filters", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
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
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          start_date: ~D[2026-02-24],
          trip_id: "trip2",
          direction_id: 1,
          route_id: "route2",
          start_time: "11:00:00",
          revenue: :NON_REVENUE,
          stop_id: "stop2",
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

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
        arrived: 1_771_966_486,
        departed: 1_771_967_246
      }

      State.StopEvent.new_state([stop_event])

      response = get(conn, stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1"}}))
      assert validate_resp_schema(response, schema, "StopEvents")
    end

    test "can filter by trip", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by stop", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip1-route1-v1-2",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 2,
          arrived: 1_771_967_286,
          departed: 1_771_967_333
        }
      ])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"stop" => "stop2"}}))

      assert [%{"id" => "trip1-route1-v1-2"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"route" => "route1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by direction_id", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 1,
          route_id: "route2",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn =
        get(conn, stop_event_path(conn, :index, %{"filter" => %{"direction_id" => "0"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by vehicle", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn = get(conn, stop_event_path(conn, :index, %{"filter" => %{"vehicle" => "v1"}}))

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by vehicle and route simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route1-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"vehicle" => "v1", "route" => "route1"}
          })
        )

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route and direction_id simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route1-v2-2",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 1,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        },
        %StopEvent{
          id: "trip3-route2-v3-3",
          vehicle_id: "v3",
          trip_id: "trip3",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop3",
          start_date: ~D[2026-02-24],
          start_time: "12:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_969_000,
          departed: 1_771_969_100
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"route" => "route1", "direction_id" => "0"}
          })
        )

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by trip and stop simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip1-route1-v1-2",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 2,
          arrived: 1_771_967_286,
          departed: 1_771_967_333
        },
        %StopEvent{
          id: "trip2-route1-v2-2",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{"filter" => %{"trip" => "trip1", "stop" => "stop2"}})
        )

      assert [%{"id" => "trip1-route1-v1-2"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route, stop, and direction_id simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route1-1",
          trip_id: "trip2",
          direction_id: 1,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        },
        %StopEvent{
          id: "trip3-route1-v3-2",
          vehicle_id: "v3",
          trip_id: "trip3",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "12:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_969_000,
          departed: 1_771_969_100
        },
        %StopEvent{
          id: "trip4-route2-v4-1",
          vehicle_id: "v4",
          trip_id: "trip4",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "13:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_970_000,
          departed: 1_771_970_200
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"route" => "route1", "stop" => "stop1", "direction_id" => "0"}
          })
        )

      assert [%{"id" => "trip1-route1-v1-1"}] = json_response(conn, 200)["data"]
    end

    test "can filter by multiple trips, routes, and stops simultaneously", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip2-route1-v2-2",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "11:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_968_343,
          departed: nil
        },
        %StopEvent{
          id: "trip3-route2-v3-3",
          vehicle_id: "v3",
          trip_id: "trip3",
          direction_id: 0,
          route_id: "route2",
          stop_id: "stop3",
          start_date: ~D[2026-02-24],
          start_time: "12:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_969_000,
          departed: 1_771_969_100
        },
        %StopEvent{
          id: "trip2-route2-v2-1",
          vehicle_id: "v2",
          trip_id: "trip2",
          direction_id: 1,
          route_id: "route2",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "13:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_970_000,
          departed: 1_771_970_200
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"trip" => "trip1,trip2", "route" => "route1,route2", "stop" => "stop1"}
          })
        )

      response = json_response(conn, 200)["data"]
      ids = response |> Enum.map(& &1["id"]) |> Enum.sort()
      # Both trip1-route1-stop1 and trip2-route2-stop1 match the filters
      assert ids == ["trip1-route1-v1-1", "trip2-route2-v2-1"]
    end

    test "returns empty when filters match no records", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        }
      ])

      conn =
        get(
          conn,
          stop_event_path(conn, :index, %{
            "filter" => %{"route" => "route1", "direction_id" => "1"}
          })
        )

      assert [] = json_response(conn, 200)["data"]
    end

    test "pagination works", %{conn: conn} do
      State.StopEvent.new_state([
        %StopEvent{
          id: "trip1-route1-v1-1",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop1",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 1,
          arrived: 1_771_966_486,
          departed: 1_771_967_246
        },
        %StopEvent{
          id: "trip1-route1-v1-2",
          vehicle_id: "v1",
          trip_id: "trip1",
          direction_id: 0,
          route_id: "route1",
          stop_id: "stop2",
          start_date: ~D[2026-02-24],
          start_time: "10:00:00",
          revenue: :REVENUE,
          stop_sequence: 2,
          arrived: 1_771_967_286,
          departed: 1_771_967_333
        }
      ])

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
  end

  describe "show_data/2" do
    test "shows chosen resource", %{conn: conn} do
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
        arrived: 1_771_966_486,
        departed: 1_771_967_246
      }

      State.StopEvent.new_state([stop_event])

      conn = get(conn, stop_event_path(conn, :show, stop_event.id))
      assert json_response(conn, 200)["data"]["id"] == stop_event.id
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
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
        arrived: 1_771_966_486,
        departed: 1_771_967_246
      }

      State.StopEvent.new_state([stop_event])

      response = get(conn, stop_event_path(conn, :show, stop_event.id))
      assert validate_resp_schema(response, schema, "StopEvent")
    end

    test "does not show resource when id is nonexistent", %{conn: conn} do
      conn = get(conn, stop_event_path(conn, :show, "nonexistent"))
      assert json_response(conn, 404)
    end
  end
end
