defmodule ApiWeb.StopEventViewTest do
  use ApiWeb.ConnCase

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.StopEvent

  @stop_event %StopEvent{
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

  @trip %Model.Trip{
    id: "trip1",
    route_id: "route1",
    name: "Test Trip",
    direction_id: 0,
    service_id: "service1",
    headsign: "Testination",
    wheelchair_accessible: 1,
    bikes_allowed: 1,
    revenue: :REVENUE
  }

  @stop %Model.Stop{
    id: "stop1",
    name: "Test Stop",
    latitude: 42.0,
    longitude: -71.0,
    wheelchair_boarding: 0,
    location_type: 0
  }

  @route %Model.Route{
    id: "route1",
    agency_id: "agency1",
    color: "FF0000",
    description: "Test Route",
    sort_order: 1,
    text_color: "FFFFFF",
    line_id: "line1",
    listed_route: true,
    type: 3
  }

  @route_pattern %Model.RoutePattern{
    id: "route1-_-0"
  }

  @vehicle %Model.Vehicle{
    id: "v1",
    current_status: :IN_TRANSIT_TO,
    updated_at: ~U[2026-02-24 15:30:00Z],
    revenue: :REVENUE
  }

  @schedule %Model.Schedule{
    direction_id: 0,
    route_id: "route1",
    service_id: "service1",
    stop_sequence: 1,
    stop_id: "stop1",
    timepoint?: false,
    trip_id: "trip1"
  }

  setup %{conn: conn} do
    conn = Phoenix.Controller.put_view(conn, ApiWeb.StopEventView)
    {:ok, %{conn: conn}}
  end

  test "renders stop event with all attributes", %{conn: conn} do
    rendered = render(ApiWeb.StopEventView, "index.json-api", data: @stop_event, conn: conn)

    assert rendered["data"]["type"] == "stop_event"
    assert rendered["data"]["id"] == "trip1-route1-v1-1"

    assert rendered["data"]["attributes"] == %{
             "start_date" => ~D[2026-02-24],
             "direction_id" => 0,
             "revenue" => :REVENUE,
             "stop_sequence" => 1,
             "arrived" => "2026-02-24T15:28:06Z",
             "departed" => "2026-02-24T15:40:46Z"
           }
  end

  test "renders stop event with nil arrived (first stop)", %{conn: conn} do
    stop_event = %StopEvent{@stop_event | arrived: nil}
    rendered = render(ApiWeb.StopEventView, "index.json-api", data: stop_event, conn: conn)

    assert rendered["data"]["attributes"]["arrived"] == nil
    assert rendered["data"]["attributes"]["departed"] == "2026-02-24T15:40:46Z"
  end

  test "renders stop event with nil departed (last or current stop)", %{conn: conn} do
    stop_event = %StopEvent{@stop_event | departed: nil}
    rendered = render(ApiWeb.StopEventView, "index.json-api", data: stop_event, conn: conn)

    assert rendered["data"]["attributes"]["arrived"] == "2026-02-24T15:28:06Z"
    assert rendered["data"]["attributes"]["departed"] == nil
  end

  test "does not include attributes when empty set is requested", %{conn: conn} do
    # JSON:API sparse fieldsets: when client requests empty field list,
    # no attributes are returned (only id, type, and relationships)
    conn = assign(conn, :opts, %{fields: %{"stop_event" => []}})

    rendered =
      render(ApiWeb.StopEventView, "index.json-api",
        data: @stop_event,
        conn: conn,
        opts: conn.assigns.opts
      )

    assert rendered["data"]["attributes"] == %{}
  end

  describe "relationships" do
    setup do
      State.Trip.new_state([@trip])
      State.Stop.new_state([@stop])
      State.Route.new_state([@route])
      State.Vehicle.new_state([@vehicle])
      :ok
    end

    test "includes all default relationships but no optional relationships", %{conn: conn} do
      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn
        )

      relationships = rendered["data"]["relationships"]
      assert relationships["trip"]["data"]["id"] == "trip1"
      assert relationships["stop"]["data"]["id"] == "stop1"
      assert relationships["route"]["data"]["id"] == "route1"
      assert relationships["vehicle"]["data"]["id"] == "v1"
      refute Map.has_key?(relationships, "schedule")
    end

    test "preloads schedules for multiple stop_events", %{conn: conn} do
      State.RoutePattern.new_state([@route_pattern])

      schedule2 = %Model.Schedule{
        direction_id: 0,
        route_id: "route1",
        service_id: "service1",
        stop_sequence: 2,
        stop_id: "stop1",
        timepoint?: false,
        trip_id: "trip1"
      }

      State.Schedule.new_state([@schedule, schedule2])
      State.RoutesPatternsAtStop.update!()

      stop_event2 = %StopEvent{@stop_event | id: "trip1-route1-v1-2", stop_sequence: 2}

      conn =
        %{conn | params: %{"include" => "schedule"}}
        |> ApiWeb.ApiControllerHelpers.split_include([])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: [@stop_event, stop_event2],
          conn: conn
        )

      assert length(rendered["data"]) == 2
      # Verify schedules were bulk loaded via schedule_for_many
      assert get_in(rendered, ["data", Access.at(0), "relationships", "schedule", "data", "id"]) ==
               "schedule-trip1-stop1-1"

      assert get_in(rendered, ["data", Access.at(1), "relationships", "schedule", "data", "id"]) ==
               "schedule-trip1-stop1-2"
    end

    test "includes schedule relationship plus all default relationships when requested", %{
      conn: conn
    } do
      State.RoutePattern.new_state([@route_pattern])
      State.Schedule.new_state([@schedule])
      State.RoutesPatternsAtStop.update!()

      conn =
        %{conn | params: %{"include" => "schedule,trip,stop,route,vehicle"}}
        |> ApiWeb.ApiControllerHelpers.split_include([])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn
        )

      relationships = rendered["data"]["relationships"]
      assert relationships["trip"]["data"]["id"] == "trip1"
      assert relationships["stop"]["data"]["id"] == "stop1"
      assert relationships["route"]["data"]["id"] == "route1"
      assert relationships["vehicle"]["data"]["id"] == "v1"
      assert relationships["schedule"]["data"]["id"] == "schedule-trip1-stop1-1"
    end

    test "returns nil schedule when schedule does not exist", %{conn: conn} do
      # Set up required state but no schedule
      State.RoutePattern.new_state([@route_pattern])
      State.Schedule.new_state([])
      State.RoutesPatternsAtStop.update!()

      conn =
        %{conn | params: %{"include" => "schedule"}}
        |> ApiWeb.ApiControllerHelpers.split_include([])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn
        )

      # Schedule relationship should be present but with nil data
      assert get_in(rendered, ["data", "relationships", "schedule", "data"]) == nil
    end
  end
end
