defmodule ApiWeb.FacilityViewTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.FacilityView
  alias Model.Facility

  @facility %Facility{
    id: "id",
    stop_id: "place-sstat",
    name: "name",
    short_name: "short_name",
    type: "ESCALATOR",
    latitude: 42.260381,
    longitude: -71.794593
  }

  setup do
    State.Facility.Property.new_state([])
    :ok
  end

  test "can do a basic rendering", %{conn: conn} do
    rendered = render("index.json-api", data: @facility, conn: conn)["data"]
    assert rendered["type"] == "facility"
    assert rendered["id"] == "id"

    assert rendered["attributes"] == %{
             "name" => @facility.name,
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
end
