defmodule ApiWeb.TripViewTest do
  use ApiWeb.ConnCase
  use Timex

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.{CommuterRailOccupancy, Schedule, Stop, Trip}

  @trip %Trip{
    id: "trip",
    name: "123",
    headsign: "North Station",
    direction_id: 0,
    wheelchair_accessible: 1,
    route_id: "CR-Lowell",
    service_id: "service",
    shape_id: "shape",
    block_id: "block",
    bikes_allowed: 0,
    route_pattern_id: "CR-Lowell-1-0"
  }

  @occupancy %CommuterRailOccupancy{
    trip_name: "123",
    percentage: 30,
    status: :many_seats_available
  }

  @schedule %Schedule{
    trip_id: "trip",
    route_id: "route",
    stop_id: "stop1",
    direction_id: 1,
    arrival_time: 100,
    departure_time: 90_000,
    stop_sequence: 1,
    pickup_type: 2,
    drop_off_type: 3,
    timepoint?: true
  }

  @stop %Stop{id: "stop1"}

  setup do
    State.Trip.new_state([@trip])
    State.CommuterRailOccupancy.new_state([@occupancy])
    State.Schedule.new_state([@schedule])
    State.Stop.new_state([@stop])
    :ok
  end

  test "render returns JSONAPI", %{conn: conn} do
    rendered = render(ApiWeb.TripView, "index.json-api", data: @trip, conn: conn)
    assert rendered["data"]["type"] == "trip"
    assert rendered["data"]["id"] == "trip"

    assert rendered["data"]["attributes"] == %{
             "direction_id" => 0,
             "name" => "123",
             "headsign" => "North Station",
             "wheelchair_accessible" => 1,
             "block_id" => "block",
             "bikes_allowed" => 0
           }

    assert rendered["data"]["relationships"] ==
             %{
               "route" => %{"data" => %{"type" => "route", "id" => "CR-Lowell"}},
               "service" => %{"data" => %{"type" => "service", "id" => "service"}},
               "shape" => %{"data" => %{"type" => "shape", "id" => "shape"}},
               "route_pattern" => %{
                 "data" => %{"type" => "route_pattern", "id" => "CR-Lowell-1-0"}
               }
             }
  end

  test "render includes the vehicle if explicitly included", %{conn: conn} do
    conn =
      conn
      |> Map.put(:params, %{"include" => "vehicle"})
      |> ApiWeb.ApiControllerHelpers.split_include([])

    rendered = render(ApiWeb.TripView, "index.json-api", data: @trip, conn: conn)
    refute rendered["data"]["relationships"]["vehicle"] == nil
  end

  test "doesn't include stops if not explicitly included", %{conn: conn} do
    rendered = render(ApiWeb.TripView, "index.json-api", data: @trip, conn: conn)
    assert rendered["data"]["relationships"]["stops"] == nil
  end

  test "render includes stop list if explicitly included", %{conn: conn} do
    conn =
      conn
      |> Map.put(:params, %{"include" => "stops"})
      |> ApiWeb.ApiControllerHelpers.split_include([])

    rendered = render(ApiWeb.TripView, "index.json-api", data: @trip, conn: conn)
    assert %{"data" => [_ | _]} = rendered["data"]["relationships"]["stops"]
  end

  test "cannot include occupancies if experimental features are not enabled", %{conn: conn} do
    rendered =
      render(ApiWeb.TripView, "index.json-api",
        data: @trip,
        conn: conn,
        opts: [include: "occupancies"]
      )

    assert %{"data" => []} = rendered["data"]["relationships"]["occupancies"]
  end

  test "can include occupancies if experimental features are enabled", %{conn: conn} do
    conn = assign(conn, :experimental_features_enabled?, true)

    rendered =
      render(ApiWeb.TripView, "index.json-api",
        data: @trip,
        conn: conn,
        opts: [include: "occupancies"]
      )

    assert %{"data" => [_ | _]} = rendered["data"]["relationships"]["occupancies"]
  end

  test "does not include occupancies by default", %{conn: conn} do
    conn = assign(conn, :experimental_features_enabled?, true)

    rendered = render(ApiWeb.TripView, "index.json-api", data: @trip, conn: conn)

    refute rendered["data"]["relationships"]["occupancies"]
  end
end
