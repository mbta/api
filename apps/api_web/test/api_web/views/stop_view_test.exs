defmodule ApiWeb.StopViewTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: true
  import Phoenix.View
  import ApiWeb.StopView
  alias ApiWeb.StopView
  alias Model.Stop

  @stop %Stop{
    id: "72",
    name: "Massachusetts Ave @ Pearl St",
    description: "description",
    latitude: 42.364915,
    longitude: -71.103074,
    municipality: "Cambridge",
    on_street: "Massachusetts Avenue",
    at_street: "Essex Street",
    vehicle_type: 3
  }

  setup %{conn: conn} do
    conn = Phoenix.Controller.put_view(conn, StopView)
    {:ok, %{conn: conn}}
  end

  test "can do a basic rendering", %{conn: conn} do
    rendered = render("index.json-api", data: @stop, conn: conn)["data"]
    assert rendered["type"] == "stop"
    assert rendered["id"] == @stop.id

    assert rendered["attributes"] == %{
             "name" => @stop.name,
             "description" => @stop.description,
             "latitude" => @stop.latitude,
             "longitude" => @stop.longitude,
             "municipality" => @stop.municipality,
             "on_street" => @stop.on_street,
             "at_street" => @stop.at_street,
             "vehicle_type" => @stop.vehicle_type,
             "address" => nil,
             "location_type" => 0,
             "platform_code" => nil,
             "platform_name" => nil,
             "wheelchair_boarding" => 0
           }
  end

  test "encodes the self link to be URL safe", %{conn: conn} do
    id = "River Works / GE Employees Only"
    expected = "River%20Works%20%2F%20GE%20Employees%20Only"
    stop = %Stop{id: id}
    rendered = render(StopView, "index.json-api", data: stop, conn: conn)
    assert rendered["data"]["links"]["self"] == "/stops/#{expected}"
  end

  describe "show.json-api" do
    test "doesn't include a route with a single include=route query param", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"include" => "route"})
        |> Phoenix.Controller.put_view(StopView)
        |> ApiWeb.ApiControllerHelpers.split_include([])

      stop = %Stop{id: "show"}
      rendered = render(StopView, "show.json-api", data: stop, conn: conn)
      refute rendered["data"]["relationships"]["route"]
    end
  end
end
