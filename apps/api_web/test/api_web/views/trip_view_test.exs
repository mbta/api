defmodule ApiWeb.TripViewTest do
  use ApiWeb.ConnCase
  use Timex

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.Trip

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
end
