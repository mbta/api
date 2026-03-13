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
    start_time: "10:00:00",
    revenue: :REVENUE,
    stop_id: "stop1",
    stop_sequence: 1,
    arrived: ~U[2026-02-24 15:28:06Z],
    departed: ~U[2026-02-24 15:40:46Z]
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
             "vehicle_id" => "v1",
             "start_date" => ~D[2026-02-24],
             "trip_id" => "trip1",
             "direction_id" => 0,
             "route_id" => "route1",
             "start_time" => "10:00:00",
             "revenue" => :REVENUE,
             "stop_id" => "stop1",
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

  test "renders stop event with nil departed (last stop)", %{conn: conn} do
    stop_event = %StopEvent{@stop_event | departed: nil}
    rendered = render(ApiWeb.StopEventView, "index.json-api", data: stop_event, conn: conn)

    assert rendered["data"]["attributes"]["arrived"] == "2026-02-24T15:28:06Z"
    assert rendered["data"]["attributes"]["departed"] == nil
  end

  test "renders non-revenue trip", %{conn: conn} do
    stop_event = %StopEvent{@stop_event | revenue: :NON_REVENUE}
    rendered = render(ApiWeb.StopEventView, "index.json-api", data: stop_event, conn: conn)

    assert rendered["data"]["attributes"]["revenue"] == :NON_REVENUE
  end

  test "does not include values which aren't requested", %{conn: conn} do
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
    test "includes trip relationship when requested", %{conn: conn} do
      trip = %Model.Trip{
        id: "trip1",
        route_id: "route1",
        direction_id: 0
      }

      State.Trip.new_state([trip])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn,
          opts: %{include: "trip"}
        )

      assert get_in(rendered, ["data", "relationships", "trip", "data", "id"]) == "trip1"
    end

    test "includes stop relationship when requested", %{conn: conn} do
      stop = %Model.Stop{
        id: "stop1",
        name: "Test Stop"
      }

      State.Stop.new_state([stop])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn,
          opts: %{include: "stop"}
        )

      assert get_in(rendered, ["data", "relationships", "stop", "data", "id"]) == "stop1"
    end

    test "includes route relationship when requested", %{conn: conn} do
      route = %Model.Route{
        id: "route1",
        type: 3
      }

      State.Route.new_state([route])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn,
          opts: %{include: "route"}
        )

      assert get_in(rendered, ["data", "relationships", "route", "data", "id"]) == "route1"
    end

    test "includes vehicle relationship when requested", %{conn: conn} do
      vehicle = %Model.Vehicle{
        id: "v1",
        revenue: :REVENUE
      }

      State.Vehicle.new_state([vehicle])

      rendered =
        render(ApiWeb.StopEventView, "index.json-api",
          data: @stop_event,
          conn: conn,
          opts: %{include: "vehicle"}
        )

      assert get_in(rendered, ["data", "relationships", "vehicle", "data", "id"]) == "v1"
    end
  end

  describe "location" do
    test "returns the correct stop event location", %{conn: conn} do
      rendered = render(ApiWeb.StopEventView, "index.json-api", data: @stop_event, conn: conn)

      assert rendered["data"]["links"]["self"] =~ "/stop_events/trip1-route1-v1-1"
    end
  end
end
