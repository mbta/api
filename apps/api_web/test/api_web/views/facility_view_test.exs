defmodule ApiWeb.FacilityViewTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.FacilityView
  alias Model.Facility

  @facility %Facility{
    id: "id",
    stop_id: "place-sstat",
    long_name: "name",
    short_name: "short_name",
    type: "ESCALATOR",
    latitude: 42.260381,
    longitude: -71.794593
  }

  test "can do a basic rendering", %{conn: conn} do
    rendered = render("index.json-api", data: @facility, conn: conn)["data"]
    assert rendered["type"] == "facility"
    assert rendered["id"] == "id"

    assert rendered["attributes"] == %{
             "long_name" => @facility.long_name,
             "short_name" => @facility.short_name,
             "type" => @facility.type,
             "properties" => [],
             "latitude" => @facility.latitude,
             "longitude" => @facility.longitude
           }

    assert rendered["relationships"] ==
             %{
               "stop" => %{"data" => %{"type" => "stop", "id" => "place-sstat"}}
             }
  end

  test "can render properties if they're included", %{conn: conn} do
    property = %Facility.Property{
      facility_id: "id",
      name: "prop",
      value: 5
    }

    State.Facility.Property.new_state([property])

    for opts <- [[], [fields: %{"facility" => ~w(properties)a}]] do
      conn = Plug.Conn.assign(conn, :opts, opts)
      rendered = render("index.json-api", data: @facility, conn: conn)["data"]

      assert rendered["attributes"]["properties"] == [
               %{"name" => "prop", "value" => 5}
             ]
    end
  end

  test "populates name in addition to long_name for older API versions", %{conn: conn} do
    conn = assign(conn, :api_version, "2019-04-05")
    rendered = render("index.json-api", data: @facility, conn: conn)["data"]
    assert rendered["type"] == "facility"
    assert rendered["id"] == "id"

    assert rendered["attributes"] == %{
             "name" => @facility.long_name,
             "long_name" => @facility.long_name,
             "short_name" => @facility.short_name,
             "type" => @facility.type,
             "properties" => [],
             "latitude" => @facility.latitude,
             "longitude" => @facility.longitude
           }
  end

  describe "attribute_set/1" do
    test "Adds 'name' to the list of fields for older API version", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-02-12")
      result = attribute_set(conn)
      assert MapSet.member?(result, "name")
    end

    test "Doesn't add 'name' to the list of fields for newer API version", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      result = attribute_set(conn)
      refute MapSet.member?(result, "name")
    end
  end
end
