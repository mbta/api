defmodule ApiWeb.VehicleViewTest do
  use ApiWeb.ConnCase

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.Vehicle

  @vehicle %Vehicle{
    id: "vehicle",
    revenue: :REVENUE
  }

  setup %{conn: conn} do
    conn = Phoenix.Controller.put_view(conn, ApiWeb.VehicleView)
    {:ok, %{conn: conn}}
  end

  test "render returns JSONAPI", %{conn: conn} do
    rendered = render(ApiWeb.VehicleView, "index.json-api", data: @vehicle, conn: conn)
    assert rendered["data"]["type"] == "vehicle"
    assert rendered["data"]["id"] == "vehicle"

    assert rendered["data"]["attributes"] == %{
             "direction_id" => nil,
             "revenue" => "REVENUE",
             "bearing" => nil,
             "carriages" => [],
             "current_status" => nil,
             "current_stop_sequence" => nil,
             "label" => nil,
             "latitude" => nil,
             "longitude" => nil,
             "occupancy_status" => nil,
             "speed" => nil,
             "updated_at" => nil
           }
  end
end
