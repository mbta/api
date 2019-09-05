defmodule ApiWeb.ShapeViewTest do
  use ApiWeb.ConnCase

  import ApiWeb.ShapeView

  @shape %Model.Shape{
    id: "shape",
    route_id: "route",
    direction_id: 1,
    priority: 1,
    name: "origin - variant"
  }

  describe "name/2" do
    test "replaces name on versions before 2019-07-01", %{conn: conn} do
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
