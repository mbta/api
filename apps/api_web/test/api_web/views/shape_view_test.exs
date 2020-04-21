defmodule ApiWeb.ShapeViewTest do
  use ApiWeb.ConnCase

  import ApiWeb.ShapeView

  @shape %Model.Shape{
    id: "shape",
    route_id: "route",
    direction_id: 1,
    priority: 1,
    name: "origin - variant",
    polyline: "polyline_string"
  }

  describe "attributes/2" do
    test "excludes fields on versions after 2020-05-01", %{conn: conn} do
      conn = assign(conn, :api_version, "2020-05-01")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]

      assert Map.keys(rendered["attributes"]) == ["polyline"]
    end

    test "includes all fields on versions before 2020-05-01", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]

      assert Map.keys(rendered["attributes"]) == ["direction_id", "name", "polyline", "priority"]
    end
  end

  describe "relationships/2" do
    setup do
      State.Route.new_state([%Model.Route{id: "route"}])
      State.Stop.new_state([%Model.Stop{id: "stop"}])
      State.Trip.new_state([%Model.Trip{id: "trip", route_id: "route", shape_id: "shape"}])
      State.Schedule.new_state([%Model.Schedule{trip_id: "trip", stop_id: "stop"}])
      State.StopsOnRoute.update!()
      :ok
    end

    test "excludes fields on versions after 2020-05-01", %{conn: conn} do
      conn = assign(conn, :api_version, "2020-05-01")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]

      refute Map.has_key?(rendered, "relationships")
    end

    test "includes all fields on versions before 2020-05-01", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]

      assert Map.keys(rendered["relationships"]) == ["route", "stops"]
      assert rendered["relationships"]["route"]["data"]["id"] == "route"
      assert Enum.at(rendered["relationships"]["stops"]["data"], 0)["id"] == "stop"
    end
  end

  describe "name/2" do
    test "replaces name on versions before 2019-07-01", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]
      assert rendered["type"] == "shape"
      assert rendered["attributes"]["name"] == "origin - variant"

      conn = assign(conn, :api_version, "2019-02-12")
      rendered = render("index.json-api", data: @shape, conn: conn)["data"]
      assert rendered["type"] == "shape"
      assert rendered["attributes"]["name"] == "variant"
    end

    test "doesn't change name without origin", %{conn: conn} do
      shape = %{@shape | name: "variant only"}

      conn = assign(conn, :api_version, "2019-07-01")
      rendered = render("index.json-api", data: shape, conn: conn)["data"]
      assert rendered["type"] == "shape"
      assert rendered["attributes"]["name"] == "variant only"

      conn = assign(conn, :api_version, "2019-02-12")
      rendered = render("index.json-api", data: shape, conn: conn)["data"]
      assert rendered["type"] == "shape"
      assert rendered["attributes"]["name"] == "variant only"
    end
  end
end
